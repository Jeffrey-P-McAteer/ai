
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