window.play_video = function(opts, callback) {
    var url = opts.url || '';
    var time = opts.time || -1.0;
    var percentage = opts.percentage || -1.0;

    cordova.exec(callback, function(err) {
        callback("[SSVIDEO] Not able to play. Probably there's a video playing.");
    }, "SSVideo", "play", [url, percentage, time]);
};