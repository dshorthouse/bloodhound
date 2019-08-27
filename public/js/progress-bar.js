/*global jQuery, window, document, self, encodeURIComponent, Bloodhound */
var ProgressBar = (function($, window) {

  "use strict";

  var _private = {

    identifier: "",
    init: function(identifier) {
      this.identifier = typeof identifier !== 'undefined' ? identifier : "";
      this.candidate_counter();
    },
    candidate_counter: function() {
      var self = this, percent, progress_bar = $('#progress-bar_' + this.identifier);
      $.ajax({
        method: "GET",
        url: "/" + self.identifier + "/progress.json?relaxed=0"
      }).done(function(data) {
        var denominator = (data.claimed + data.unclaimed === 0) ? 1 : data.claimed + data.unclaimed;
        percent = parseInt(100 * data.claimed / denominator, 10);
        progress_bar.width(percent + '%').text(percent + "%");
        if (percent === 100) {
          progress_bar.removeClass("bg-info").addClass("bg-success");
        }
      });
    }
  };

  return {
    init: function(identifier) {
      _private.init(identifier);
    }
  };

}(jQuery, window));
