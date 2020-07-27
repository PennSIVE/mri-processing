// imports, global definitions
const electron = require('electron');
const { dialog } = electron.remote;
const { ipcRenderer } = electron;
let formData = {
  type: 'upload'
};
let uploadCounter = 0;


// functions
function selectDir(e) {
  e.preventDefault();
  const id = e.target.id;
  const path = dialog.showOpenDialog({
    properties: ['openDirectory']
  });
  path.then(values => {
    if (values.filePaths[0] !== undefined) {
      e.target.classList = 'is-valid custom-file-input';
      document.querySelectorAll('[for="' + id + '"]')[0].style.borderColor = '#28a745'
      document.getElementById(id + '-help').innerText = 'You selected ' + values.filePaths[0];
      formData[id] = values.filePaths[0];
    } else {
      e.target.classList = 'is-invalid custom-file-input';
      document.getElementById(id + '-help').innerText = 'You didn\'t select anything';
      document.querySelectorAll('[for="' + id + '"]')[0].style.borderColor = '#dc3545'
      delete formData[id]
    }
  });
}

function selectImageType(e) {
  document.getElementById('t1').classList = 'is-valid custom-control-input';
  document.getElementById('t2').classList = 'is-valid custom-control-input';
  formData.imageType = e.target.id;
}

function openITK(e) {
  e.preventDefault();
  console.log(e.target, e.target.dataset)
  ipcRenderer.send('asynchronous-message', {
    type: 'open',
    path: e.target.dataset.dir
  });
}

function disableForm(bool) {
  let buttons = document.getElementsByTagName("button");
  for (let i = 0; i < buttons.length; i++) {
    buttons[i].disabled = bool;
  }
  let inputs = document.getElementsByTagName("input");
  for (let i = 0; i < inputs.length; i++) {
    inputs[i].disabled = bool;
  }
}

function invalidForm() {
  return document.getElementById('user').checkValidity() === false ||
    document.getElementById('t1').checkValidity() === false ||
    document.getElementById('t2').checkValidity() === false ||
    formData.hasOwnProperty('imageType') === false ||
    formData.hasOwnProperty('baseline') === false ||
    formData.hasOwnProperty('followup') === false;
}


// main
(function () {
  'use strict';
  window.addEventListener('load', () => {
    ipcRenderer.on('asynchronous-message', (event, message) => {
      if (message.type === 'downloaded') {
        disableForm(false);
        document.getElementById('itk').dataset.dir = message.path;
        alert("Success! You may now open the images in ITK-SNAP");
      } else if (message === 'uploaded') {
        form.classList.add('was-validated');
        uploadCounter++;
        if (uploadCounter === 2) {
          uploadCounter = 0;
          formData.type = 'process'; // the next thing to do
          ipcRenderer.send('asynchronous-message', formData);
        }
      } else if (message === 'connError') {
        disableForm(false);
        document.getElementById('user').setCustomValidity("Incorrect username or password");
        document.getElementById('pass').setCustomValidity("Incorrect username or password");
        form.classList.add('was-validated');
      }
    });

    document.getElementById('baseline').addEventListener('click', selectDir);
    document.getElementById('followup').addEventListener('click', selectDir);
    document.getElementById('itk').addEventListener('click', openITK);
    document.getElementById('t1').addEventListener('click', selectImageType);
    document.getElementById('t2').addEventListener('click', selectImageType);
    document.getElementById('user').addEventListener('input', (e) => { formData.user = e.target.value; });

    // Fetch all the forms we want to apply custom Bootstrap validation styles to
    let forms = document.getElementsByClassName('needs-validation');
    // Loop over them and prevent submission
    let validation = Array.prototype.filter.call(forms, function (form) {
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        event.stopPropagation();
        if (invalidForm()) {
          disableForm(false);
          form.classList.add('was-validated');
        } else { // no invalid form elements
          form.classList.remove('was-validated');
          disableForm(true);
          ipcRenderer.send('asynchronous-message', formData);
        }
      }, false);
    });
  }, false);
})();