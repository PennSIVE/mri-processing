const { app, BrowserWindow, ipcMain } = require('electron');
const { autoUpdater } = require("electron-updater");
const exec = require('child_process').exec;
const path = require('path');
const fs = require('fs');
const os = require('os');
const Rsync = require('rsync');
const fixPath = require('fix-path');
let win = undefined;

function init() {
    delete process.env.DISPLAY; // req'd to ensure ssh connection terminates when executing single commands e.g. ssh user@cubic cmd
    fixPath();
    createWindow();
    autoUpdater.checkForUpdatesAndNotify();
}

function createWindow() {
    // Create the browser window.
    win = new BrowserWindow({
        width: 600,
        height: 600,
        titleBarStyle: 'hiddenInset',
        webPreferences: {
            nodeIntegration: true
        }
    })

    // and load the index.html of the app.
    win.loadFile('html/index.html')

}

function pipeline(baseline, followup, type, user) {
    const singularity = exec(`ssh -oStrictHostKeyChecking=no -o ConnectTimeout=10 -oCheckHostIP=no -oUserKnownHostsFile=/dev/null ${user}@cubic-login "rm -rf ~/.electrondata/processed ; mkdir -p ~/.electrondata/processed ; qsub -b y -terse -o /dev/null -e /dev/null -cwd WS_TYPE=${type} singularity run -B ~/.electrondata${baseline}:/baseline -B ~/.electrondata${followup}:/followup -B ~/.electrondata/processed:/processed /cbica/home/robertft/singularity_images/processing-app_latest.sif"`);
    singularity.stdout.on('data', function (data) {
        // win.webContents.send('asynchronous-message', 1);
        console.log('pipeline', data)
        // processing is going to take at least 20 mins (1200 seconds), but check if it's done every 20s thereafter
        setTimeout(() => { checkCompletion(parseInt(data), baseline, followup, user) }, 1200 * 1000)
    });
    // singularity.on('close', (code) => {
    //     if (code !== 0) {
    //         // error
    //     }
    // });
}

function checkCompletion(jobId, baseline, followup, user) {
    const ps = exec(`ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o CheckHostIP=no -o UserKnownHostsFile=/dev/null ${user}@cubic-login "qstat | grep ${jobId} | wc -l"`);
    ps.stdout.on('data', function (data) {
        if (data.trim() === '0') {
            download(user);    
        } else {
            setTimeout(() => { checkCompletion(jobId, baseline, followup, user) }, 20 * 1000)
        }
        console.log('checkCompletion', data, data.trim() === '0');
    });
}

function openITK(path) {
    exec("for filename in " + path + "/*.gz; do itksnap -g $filename; done;", (error, stdout, stderr) => {
        console.log(stdout, stderr);
    });
}

function upload(path, user) {
    const rsync = new Rsync()
        .shell('ssh')
        .flags('az')
        .source(path)
        .chmod('go-rwx')
        .owner(user)
        .group(user)
        .set('timeout', '10')
        .set('rsync-path', `mkdir -p ~/.electrondata${path} && rsync`) // https://stackoverflow.com/a/22908437/2624391
        .destination(`${user}@cubic-login:~/.electrondata${path}`);

    rsync.execute(
        function (error, code, cmd) {
            // we're done
            if (code === 0) { // success!
                win.webContents.send('asynchronous-message', 'uploaded');
            } else {
                win.webContents.send('asynchronous-message', 'connError');
            }
        }
    )

}

function download(user) {
    fs.mkdtemp(path.join(os.tmpdir(), 'processed-'), (err, folder) => {
        if (err) throw err;

        const rsync = new Rsync()
            .shell('ssh')
            .flags('az')
            .progress()
            .destination(folder)
            .set('timeout', '10')
            .source(`${user}@cubic-login:~/.electrondata/processed`);

        rsync.execute(
            function (error, code, cmd) {
                // we're done
                if (code === 0) { // success!
                    win.webContents.send('asynchronous-message', { type: 'downloaded', path: `${folder}/processed` });
                }
            }
        )
    });
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.whenReady().then(init)

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


ipcMain.on('asynchronous-message', (event, args) => {
    if (args.type === 'open') {
        openITK(args.path);
        return;
    }
    // validate args
    if (!path.isAbsolute(args.baseline) || !path.isAbsolute(args.followup) ||
        !fs.existsSync(args.baseline) || !fs.existsSync(args.followup)) {
        return;
    }
    // interpret message types
    if (args.type === 'upload') {
        upload(args.baseline, args.user);
        upload(args.followup, args.user);
    } else if (args.type === 'process') {
        pipeline(args.baseline, args.followup, args.imageType.toUpperCase(), args.user);
    }
});