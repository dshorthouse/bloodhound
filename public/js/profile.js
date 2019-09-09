/*global jQuery, window, document, self, encodeURIComponent, Profile, Bootstrap */

var Profile = (function($, window) {

  "use strict";

  var _private = {

    user_id: "",
    path: "",
    init: function(path) {
      this.path = typeof path !== 'undefined' ? path : "/profile";
      this.activate_profile_image();
      this.activate_zenodo();
      this.activate_email();
    },
    activate_profile_image: function() {
      var popup = $('#profile-upload-option'), self = this;

      $('#profile-image').on('click', function() {
        popup.show();
      });
      $('#profile-cancel').on('click', function(e) {
        e.stopPropagation();
        e.preventDefault();
        popup.hide();
      });
      $('#profile-remove').on('click', function(e) {
        e.stopPropagation();
        e.preventDefault();
        popup.hide();
        $('#profile-image').addClass("profile-image-bg")
                           .find("img").attr({width:"0px", height:"0px"})
                           .attr({src:"/images/photo.png", width:"48px", height:"96px"});
        $.ajax({
          url: self.path + '/image',
          data: {},
          type: 'DELETE'
        }).done(function(data) {
          location.reload();
        });
      });
      $('#user-image').on('change', function(e) {
        popup.hide();
        if (e.target.files[0]) {
          var reader = new FileReader();
          reader.onload = function(e) {
            var image = new Image();
            image.src = e.target.result;
            image.onload = function() {
              var dimensions = self.calculateAspectRatioFit(image.width, image.height);
              $('#profile-image').removeClass("profile-image-bg")
                                 .find("img")
                                 .attr({
                                   src:e.target.result,
                                   width:dimensions.width+"px",
                                   height:dimensions.height+"px",
                                   class:"upload-preview"
                                 });
              };
          }
          reader.readAsDataURL(e.target.files[0]);
          var data = new FormData();
          data.append('file', $('#user-image')[0].files[0]);
          $.ajax({
              url: self.path + '/image',
              data: data,
              processData: false,
              type: 'POST',
              contentType: false,
              cache: false
          }).done(function(data) {
            location.reload();
          });
        }
      });
    },
    activate_email: function() {
      var self = this;
      $("#toggle-mail").on("change", function() {
        $.ajax({
          method: "PUT",
          url: self.path + "/email_notification.json",
          dataType: "json",
          data: JSON.stringify({ wants_mail: $(this).prop("checked") })
        }).done(function(data) {
          location.reload();
        });
        return false;
      });
    },
    activate_zenodo: function() {
      $('#zenodo-disconnect').on('click', function() {
        $.ajax({
          url: '/auth/zenodo',
          type: 'DELETE',
          data: {}
        }).done(function(data) {
          $('#zenodoModal').modal('hide');
          location.reload();
        });
      });
    },
    calculateAspectRatioFit: function(srcWidth, srcHeight) {
      var ratio = 1;
      if (srcWidth > 250 || srcHeight > 250) {
        ratio = Math.min(250/srcWidth, 250/srcHeight);
      }
      return { width: srcWidth*ratio, height: srcHeight*ratio };
     }
  };

  return {
    init: function(path) {
      _private.init(path);
    }
  };

}(jQuery, window));
