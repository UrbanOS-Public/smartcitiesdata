// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import material_design_icons from 'material-design-icons/iconfont/material-icons.css'
import normalize_css from 'normalize.css'
import scss from "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'

let Hooks = {}

Hooks.showSnackbar = {
    updated() {
        let snackbar = document.getElementById("snackbar");
        snackbar.className += " show";
        setTimeout(function() { snackbar.className = snackbar.className.replace("show", ""); }, 3000);
    }
}

Hooks.readFile = {
    mounted() {
        this.el.addEventListener("change", e => {
            var file = this.el.files[0]

            fileToText(this.el.files[0]).then(fileAsText => {
                this.pushEvent("file_upload", {
                    file: fileAsText,
                    fileType: file["type"],
                    fileSize: file["size"]
                })
            })
        })
    }
}

const fileToText = file => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsText(file);
    reader.onload = () => resolve(reader.result);
    reader.onerror = error => reject(error);
});


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket('/live', Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})
liveSocket.connect()
