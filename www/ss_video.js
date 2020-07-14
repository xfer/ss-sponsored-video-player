window.play_video = function(opts, callback) {
    var url = opts.url || '';
    var positionInSeconds = opts.positionInSeconds || -1.0;
    var percentage = opts.percentage || -1.0;

    cordova.exec(callback, function(err) {
        callback('[SSVIDEO] Not able to play.');
    }, "SSVideo", "play", [url, percentage, positionInSeconds]);
};