const { app, BrowserWindow, ipcMain } = require('electron')
const exec = require('child_process').exec;

function sanityCheck() {
    let initWin = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            nodeIntegration: true
        }
    })
    initWin.loadFile('init.html')

    exec("which docker", (error, stdout, stderr) => {
        if (!error) {
            exec("which itksnap", (error, stdout, stderr) => {
                if (!error) {
                    exec("docker pull terf/image-processing:latest", (error, stdout, stderr) => {
                        initWin = null;
                        createWindow();
                    });
                }
            });
        }
    });
}

function createWindow() {
    // Create the browser window.
    const win = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            nodeIntegration: true
        }
    })

    // and load the index.html of the app.
    win.loadFile('index.html')

}

function pipeline(baseline, followup, type) {
    // SECURITY TODO: validate args if using them to exec
    // console.log('docker run -v '+baseline+':/baseline -v '+followup+':/followup -v $(pwd)/processed:/processed --rm terf/image-processing Rscript /src/app.R');
    exec('docker run -v ' + baseline + ':/baseline -v ' + followup + ':/followup -v $(pwd)/processed:/processed --rm terf/image-processing Rscript /src/app.R', {},
        function (error, stdout, stderr) {
            if (error) throw error;
            console.log(stderr + "\n" + stdout);
        }
    );
}

function openITK() {
    exec("for filename in ./processed/*.gz; do itksnap -g $filename; done;", (error, stdout, stderr) => {
        console.log(stdout, stderr);
    });
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(sanityCheck)

// Quit when all windows are closed.
app.on('window-all-closed', () => {
    // On macOS it is common for applications and their menu bar
    // to stay active until the user quits explicitly with Cmd + Q
    if (process.platform !== 'darwin') {
        app.quit()
    }
})

app.on('activate', () => {
    // On macOS it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    if (BrowserWindow.getAllWindows().length === 0) {
        createWindow()
    }
})


ipcMain.on('asynchronous-message', (event, arg) => {
    let json = JSON.parse(arg);
    if (json.type === 'submit') {
        pipeline(json.baseline, json.followup, json.imageType);
    } else if (json.type === 'open') {
        openITK();
    }
});