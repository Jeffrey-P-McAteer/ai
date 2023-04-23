
document.getElementById('q')
    .addEventListener('keyup', function(event) {
        if (event.code === 'Enter')
        {
            event.preventDefault();
            document.getElementById('question-input-form').submit();
        }
    });

function clear_question_form() {
  setTimeout(function () {
    document.getElementById('question-input-form').reset();
  }, 400);
}

function clear_document_form() {
  setTimeout(function () {
    document.getElementById('document-input-form').reset();
  }, 400);
}


function ensure_ws_connected() {
  var ws_url = location.href.replace(/https?:\/\//i, "ws://");
  console.log('Connecting to ', ws_url);
  window.ws = new WebSocket(ws_url);
  window.ws.onmessage = (event) => {
    document.getElementById('responses').innerText += event.data + '\n';
  };
}


ensure_ws_connected();

