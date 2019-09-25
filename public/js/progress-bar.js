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
      var self = this, denominator, percent, message, progress_bar = $('#progress-bar_' + this.identifier);
      $.ajax({
        method: "GET",
        url: "/" + self.identifier + "/progress.json?relaxed=0"
      }).done(function(data) {
        denominator = data.claimed + data.unclaimed;
        if (denominator === 0) {
          percent = 100;
          message = "None";
        } else {
          percent = parseInt(100 * data.claimed / denominator, 10);
          message = percent + "%";
        }
        progress_bar.width(percent + '%').text(message);
        if (message === "None") {
          progress_bar.removeClass("bg-info").addClass("bg-secondary");
        }
        if (percent === 100 && denominator > 0) {
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
