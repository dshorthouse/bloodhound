/*global jQuery, window, document, self, encodeURIComponent, Bloodhound, Application */

Array.prototype.all_unique = function () {
  "use strict";
  return this.filter(function (value, index, self) { 
    return self.indexOf(value) === index;
  });
};

// jQuery plugin to prevent double submission of forms
jQuery.fn.preventDoubleSubmission = function() {
  $(this).on('submit',function(e){
    var $form = $(this);

    if ($form.data('submitted') === true) {
      // Previously submitted - don't submit again
      e.preventDefault();
    } else {
      // Mark it so that the next submit can be ignored
      $form.data('submitted', true);
    }
  });

  // Keep chainability
  return this;
};

var Application = (function($, window) {

  "use strict";

  var _private = {

    user_id: "",
    path: "",
    method: "POST",
    spinner: "<div class=\"spinner-grow\" role=\"status\"><span class=\"sr-only\">Loading...</span></div>",
    data_sources: { agent: {}, user : {}, organization : {} },
    init: function(user_id, method, path, identifier) {
      this.user_id = typeof user_id !== 'undefined' ? user_id : "";
      this.method = typeof method !== 'undefined' ? method : "POST";
      this.path = typeof path !== 'undefined' ? path : "";
      this.identifier = typeof identifier !== 'undefined' ? identifier : "";
      this.profile_cards();
      this.bloodhound();
      this.typeahead();
      this.activate_radios();
      this.activate_switch();
      this.activate_refresh();
      this.candidate_counter();
      this.helper_navbar();
      this.helper_modal();
    },
    profile_cards: function() {
      $(".card-profile").on("click", function() {
        window.location = $(this).find(".card-header a").attr("href");
      });
    },
    bloodhound: function() {
      this.data_sources.agent = this.create_bloodhound("agent");
      this.data_sources.agent.initialize();
      this.data_sources.user = this.create_bloodhound("user");
      this.data_sources.user.initialize();
      this.data_sources.organization = this.create_bloodhound("organization");
      this.data_sources.organization.initialize();
    },
    create_bloodhound: function(type) {
      return new Bloodhound({
        datumTokenizer : Bloodhound.tokenizers.whitespace,
        queryTokenizer : Bloodhound.tokenizers.whitespace,
        sufficient : 10,
        remote : {
          url : "/"+type+".json?q=%QUERY",
          wildcard : "%QUERY",
          transform : function(r) {
            return $.map(r, function (v) { v.type = type; return v; });
          }
        }
      });
    },
    typeahead: function(){
      var self = this;
      $("#typeahead-agent").typeahead({
          minLength: 3,
          highlight: true
        },
        {
          name: "agent",
          limit: 10,
          source : this.data_sources.agent.ttAdapter(),
          display : "fullname_reverse"
        }
        ).on("typeahead:select", function(obj, datum) {
          if (self.path === "/admin") {
            var identifier = window.location.pathname.split("/")[3];
            window.location.href = "/admin/user/" + identifier + "/candidates/agent/" + datum.id;
          } else if (self.path === "/agents") {
            window.location.href = "/agents?q=" + encodeURI(datum.fullname_reverse);
          } else {
            window.location.href = "/profile/candidates/agent/" + datum.id;
          }
        });

      $("#typeahead-user").typeahead({
          minLength: 3,
          highlight: true
        },
        {
          name: "user",
          source : this.data_sources.user.ttAdapter(),
          display : "fullname_reverse"
        }
        ).on("typeahead:select", function(obj, datum) {
          var identifier = datum.orcid || datum.wikidata;
          if (self.path === "/admin") {
            window.location.href = "/admin/user/" + identifier;
          } else if (self.path === "/roster") {
            window.location.href = "/" + identifier;
          } else {
            window.location.href = "/help-others/" + identifier;
          }
        });

        $("#typeahead-organization").typeahead({
            minLength: 3,
            highlight: true
          },
          {
            name: "organization",
            source : this.data_sources.organization.ttAdapter(),
            display : "name"
          }
          ).on("typeahead:select", function(obj, datum) {
            if (self.path === "/admin") {
              window.location.href = "/admin/organization/" + datum.id;
            } else {
              window.location.href = "/organization/" + datum.preferred;
            }
          });

    },
    activate_switch: function() {
      var self = this;
      $("#toggle-public").on("change", function() {
        $.ajax({
          method: "PUT",
          url: self.path + "/visibility.json?user_id=" + self.user_id,
          dataType: "json",
          data: JSON.stringify({ is_public: $(this).prop("checked") })
        }).done(function(data) {
          location.reload();
        });
        return false;
      });
    },
    activate_radios: function(){
      var self = this, url = "", identifier = "";

	    if (self.path === "/profile") {
	      url = self.path + "/candidates";
	    } else if (self.path === "/admin") {
        identifier = window.location.pathname.split("/")[3];
	      url = self.path + "/user/" + identifier + "/candidates";
	    } else if (self.path === "/help-others") {
        identifier = window.location.pathname.split("/")[2];
	      url = self.path + "/" + identifier;
	    }

      $("#relaxed").on("change", function() {
        if ($(this).prop("checked")) {
          window.location.href = url + "?relaxed=1";
        } else {
          window.location.href = url;
        }
        return false;
      });

      $("input.action-radio").on("change", function() {
          var row = $(this).parents("tr"),
              action = $(this).attr("data-action"),
              label = $(this).parent(),
              input = $(this);

          if($(this).attr("name") === "selection-all") {
              var occurrence_ids = $.map($("[data-occurrence-id]"), function(e) {
                return $(e).attr("data-occurrence-id");
              }).all_unique().toString();
              $.ajax({
                  method: self.method,
                  url: self.path + "/user-occurrence/bulk.json",
                  dataType: "json",
                  data: JSON.stringify({
                    user_id: self.user_id,
                    occurrence_ids: occurrence_ids,
                    action: action,
                    visible: true
                  }),
                  beforeSend: function(xhr) {
                    $(".table label").addClass("disabled");
                    $(".table button").addClass("disabled");
                  }
              }).done(function(data) {
                if (self.method === "POST" || input.hasClass("restore-ignored")) {
                  $(".table tbody tr").fadeOut(250).promise().done(function() {
                    $(this).remove();
                    $(".table tbody").append("<tr><td colspan=\"10\">" + self.spinner + "</td></tr>");
                    location.reload();
                  });
                } else {
                  $("label").each(function() {
                      $(this).removeClass("active").removeClass("disabled");
                      if($("input:first-child", this).attr("data-action") === action) {
                        $(this).addClass("active");
                      }
                  });
                  $(".table button").removeClass("disabled");
                }
              });
          } else {
              var occurrence_id = $(this).attr("data-occurrence-id");
              $.ajax({
                  method: self.method,
                  url: self.path + "/user-occurrence/" + occurrence_id + ".json",
                  dataType: "json",
                  data: JSON.stringify({
                    user_id: self.user_id,
                    action: action,
                    visible: true
                  }),
                  beforeSend: function(xhr) {
                    $("label", row).addClass("disabled");
                    $("button", row).addClass("disabled");
                  }
              }).done(function(data) {
                if(self.method === "POST" || input.hasClass("restore-ignored")) {
                  input.parents("tr").fadeOut(250).promise().done(function() {
                    $(this).remove();
                    if ($("input.action-radio").length <= 6) {
                      $(".table tbody").append("<tr><td colspan=\"10\">" + self.spinner + "</td></tr>");
                      location.reload();
                    }
                  });
                } else {
                  $("label", row).removeClass("active").removeClass("disabled");
                  label.addClass("active");
                  $("button", row).removeClass("disabled");
                }
              });
          }
          return false;
      });
      $("button.remove").on("click", function() {
        var occurrence_id = $(this).attr("data-occurrence-id"),
            row = $(this).parents("tr");
        $.ajax({
            method: "DELETE",
            url: self.path + "/user-occurrence/" + occurrence_id + ".json",
            data: JSON.stringify({ user_id: self.user_id }),
            beforeSend: function(xhr) {
              $("label", row).addClass("disabled");
              $("button", row).addClass("disabled");
            }
        }).done(function(data) {
          row.fadeOut(250, function() {
            row.remove();
            if ($("button.remove").length === 0) {
              location.reload();
            }
          });
        });
        return false;
      });
      $("button.hide-all").on("click", function() {
        var occurrence_ids = $.map($("[data-occurrence-id]"), function(e) {
              return $(e).attr("data-occurrence-id");
            }).all_unique().toString();
        $.ajax({
            method: self.method,
            url: self.path + "/user-occurrence/bulk.json",
            dataType: "json",
            data: JSON.stringify({
              user_id: self.user_id,
              occurrence_ids: occurrence_ids,
              visible: 0
            }),
            beforeSend: function(xhr) {
              $(".table label").addClass("disabled");
              $(".table button").addClass("disabled");
            }
        }).done(function(data) {
          $(".table tbody tr").fadeOut(250).promise().done(function() {
            $(this).remove();
            $(".table tbody").append("<tr><td colspan=\"10\">" + self.spinner + "</td></tr>");
            location.reload();
          });
        });
        return false;
      });
      $("button.hide").on("click", function() {
        var occurrence_id = $(this).attr("data-occurrence-id"),
            row = $(this).parents("tr");
        $.ajax({
            method: self.method,
            url: self.path + "/user-occurrence/" + occurrence_id + ".json",
            dataType: "json",
            data: JSON.stringify({ user_id: self.user_id, visible: 0}),
            beforeSend: function(xhr) {
              $("label", row).addClass("disabled");
              $("button", row).addClass("disabled");
            }
        }).done(function(data) {
          row.fadeOut(250, function() {
            row.remove();
            if ($("button.hide").length === 0) {
              location.reload();
            }
          });
        });
        return false;
      });
    },
    activate_refresh: function(){
      var self = this;
      $("a.profile-refresh").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: self.path + "/refresh.json?user_id=" + self.user_id,
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").addClass("fa-spin");
            }
        }).done(function(data) {
          button.find("i").removeClass("fa-spin");
          $(".alert").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });
      $("a.organization-refresh").on("click", function(e) {
        var button = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: button.attr("href"),
            beforeSend: function(xhr) {
              button.addClass("disabled").find("i").addClass("fa-spin");
            }
        }).done(function(data) {
          $(".alert").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });
    },
    candidate_counter: function() {
      var self = this;
      if (self.path === "/profile" || (self.path === "/admin" && self.user_id) || (self.path === "/help-others" && self.user_id)) {
        $.ajax({
          method: "GET",
          url: self.path + "/candidate-count.json?relaxed=0&user_id=" + self.user_id
        }).done(function(data) {
          if (data.count > 0 && data.count <= 50) {
            $(".badge-notify").text(data.count).show();
          } else if (data.count > 50) {
            $(".badge-notify").text("50+").show();
          }
        });
      }
    },
    helper_navbar: function() {
      var self = this;
      if ($('#helper-info').length && $('#helper-navbar').length) {
        if (self.path === "/help-others" || self.path === "/admin") {
          var navbar = $('#helper-navbar');
          $(document).scroll(function() {
            if ($(this).scrollTop() > $('#helper-info').offset().top) {
              navbar.removeClass('d-none');
            } else {
              navbar.addClass('d-none');
            }
          });
        }
      }
    },
    helper_modal: function() {
      var self = this, helper_list = "";
      $('#helperPublicModal').on('show.bs.modal', function (event) {
        var helpers_list = $("#helpers-list").hide().next();
        $("#helpers-list-none").hide();
        helpers_list.empty();
        $('#visibility-form').preventDoubleSubmission();
        $.ajax({
          method: "GET",
          url: "/help-others/" + self.identifier + "/helpers.json"
        }).done(function(data) {
          if (data.helpers.length > 0) {
            helper_list = $.map(data.helpers, function(i) {
              var email = "";
              if (i.email && i.email.length > 0) {
                email = " (" + i.email + ")";
              }
              return "<li>" + i.given + " " + i.family + email + "</li>";
            });
            helpers_list.append(helper_list.join("")).prev().show();
          } else {
            $("#helpers-list-none").show();
          }
        });
      });
    }
  };

  return {
    init: function(user_id, method, path, identifier) {
      _private.init(user_id, method, path, identifier);
    }
  };

}(jQuery, window));
