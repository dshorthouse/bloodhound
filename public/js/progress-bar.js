/*global jQuery, window, document, self, encodeURIComponent, Bloodhound */
var ProgressBar = (function($, window) {

  "use strict";

  var _private = {

    user_id: "",
    init: function(user_id) {
      this.user_id = typeof user_id !== 'undefined' ? user_id : "";
      this.candidate_counter();
    },
    candidate_counter: function() {
      var self = this, percent, progress_bar = $('#progress-bar');
      $.ajax({
        method: "GET",
        url: "/" + self.user_id + "/progress.json?relaxed=0"
      }).done(function(data) {
        percent = parseInt(100 * data.claimed / (data.claimed + data.unclaimed), 10);
        progress_bar.width(percent + '%').text(percent + "%");
        if (percent === 100) {
          progress_bar.removeClass("bg-info").addClass("bg-success");
        }
      });
    }
  };

  return {
    init: function(user_id) {
      _private.init(user_id);
    }
  };

}(jQuery, window));
