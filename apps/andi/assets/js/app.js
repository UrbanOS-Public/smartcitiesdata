// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import 'tippy.js/dist/tippy.css';
import normalize_css from 'normalize.css'
import scss from "../css/app.scss"

import tippy from 'tippy.js';

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
        setTimeout(function() { snackbar.className = snackbar.className.replace(" show", ""); }, 3000);
    }
}

Hooks.prettify = {
    mounted() {
        this.el.value =  prettifyJsonString(this.el.value);
    }
}

Hooks.readFile = {
    mounted() {
        this.el.addEventListener("change", e => {
            this.pushEvent("file_upload_started");
            var file = this.el.files[0];

            fileToText(this.el.files[0]).then(fileAsText => {
                this.pushEvent("file_upload", {
                    file: fileAsText,
                    fileType: file["type"],
                    fileSize: file["size"]
                });
            }, reason => {
                reason == "aborted" && this.pushEvent("file_upload_cancelled");
            });
        })
    }
}

Hooks.addTooltip = {
    mounted() {
        const element = this.el;
        const initialContent = element.dataset.tooltipContent;
        tippy(element, {
            content: initialContent,
            allowHTML: true,
            interactive: true,
            maxWidth: "none",
            onShow(instance) {
                const updatedContent = element.dataset.tooltipContent;
                instance.setContent(updatedContent);
            }
        });
    }
}

const prettifyJsonString = (str) => {
    try {
        var json = JSON.parse(str);
        var json_string = JSON.stringify(json, undefined, 4);
        return json_string;
    } catch (error) {
        return str;
    }
};

const fileToText = (file) => new Promise((resolve, reject) => {
    var fileInput = file["type"] == "text/csv" ? file.slice(0, 1500) : file
    var reader = new FileReader();
    var totalBytes = fileInput["size"];
    var CHUNK_SIZE = 1024;
    var offset = 0;
    var fileString = "";

    reader.onabort = () => reject("aborted");

    reader.onerror = error => reject(error);

    document.getElementById("reader-cancel").addEventListener("click", () => {
        reader.abort();
    })

    reader.onload = () => {
        fileString += reader.result;
        offset += CHUNK_SIZE;

        if(offset >= totalBytes) {
            resolve(fileString);
        } else {
            var slice = fileInput.slice(offset, offset + CHUNK_SIZE);
            reader.readAsText(slice);
        }
    }

    reader.readAsText(fileInput.slice(0, CHUNK_SIZE));
});


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket('/live', Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})
liveSocket.connect()

