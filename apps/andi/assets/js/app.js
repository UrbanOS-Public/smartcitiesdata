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
        setTimeout(function() { snackbar.className = snackbar.className.replace("show", ""); }, 3000);
    }
}

Hooks.addTooltip = {
    mounted() {
        const element = this.el;
        const initialContent = element.dataset.tooltipContent;
        tippy(this.el, {
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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket('/live', Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})
liveSocket.connect()

