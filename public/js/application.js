/*global jQuery, window, document, self, encodeURIComponent, Bloodhound, Application */

Array.prototype.all_unique = function () {
  "use strict";
  return this.filter(function (value, index, self) {
    return self.indexOf(value) === index;
  });
};

jQuery.fn.preventDoubleSubmission = function() {
  $(this).on('submit',function(e){
    var $form = $(this);

    if ($form.data('submitted') === true) {
      e.preventDefault();
    } else {
      $form.data('submitted', true);
    }
  });
  return this;
};

var Application = (function($, window) {

  "use strict";

  var _private = {

    user_id: "",
    path: "",
    method: "POST",
    identifier: "",
    spinner: "<div class=\"spinner-grow\" role=\"status\"><span class=\"sr-only\">Loading...</span></div>",
    data_sources: { agent: {}, user : {}, organization : {} },
    init: function(user_id, method, path, identifier) {
      this.user_id = typeof user_id !== 'undefined' ? user_id : "";
      this.method = typeof method !== 'undefined' ? method : "POST";
      this.path = typeof path !== 'undefined' ? path : "";
      this.identifier = typeof identifier !== 'undefined' ? identifier : "";
      $.ajaxSetup({
        headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
      });
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
      $(".card-profile").on("click", function(e) {
        e.stopPropagation();
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
      this.data_sources.dataset = this.create_bloodhound("dataset");
      this.data_sources.dataset.initialize();
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
          limit: 10,
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
          minLength: 1,
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

      $("#typeahead-dataset").typeahead({
          minLength: 1,
          highlight: true
        },
        {
          name: "dataset",
          limit: 10,
          source : this.data_sources.dataset.ttAdapter(),
          display : "title"
        }
        ).on("typeahead:select", function(obj, datum) {
          if (self.path === "/admin") {
            window.location.href = "/admin/dataset/" + datum.datasetkey;
          } else if (self.path === "/help-others") {
            window.location.href = "/help-others/" + self.identifier + "?datasetKey=" + datum.datasetkey;
          } else {
            window.location.href = "/dataset/" + datum.datasetkey;
          }
        });

    },
    activate_switch: function() {
      $("#toggle-public").on("change", function() {
        $.ajax({
          method: "PUT",
          url: $(this).attr("data-url"),
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
        url = new URL(window.location.href);
        if ($(this).prop("checked")) {
          url.searchParams.set('relaxed', 1);
          window.location.href = url.href;
        } else {
          url.searchParams.set('relaxed', 0);
          window.location.href = url.href;
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
            data: JSON.stringify({ user_id: self.user_id, visible: 0 }),
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
      $("button.thanks").on("click", function(e) {
        e.stopPropagation();

        var button = this,
            recipient_identifier = $(this).attr("data-recipient-identifier");
        $.ajax({
          method: "POST",
          url: self.path + "/message.json",
          dataType: "json",
          data: JSON.stringify({
            recipient_identifier: recipient_identifier
          })
        }).done(function(data) {
          $(button).removeClass("btn-outline-danger")
                   .addClass("btn-outline-success")
                   .addClass("disabled")
                   .prop("disabled", true)
                   .find("i").removeClass("fa-heart").addClass("fa-check");
        });
      });
    },
    activate_refresh: function(){
      var self = this;
      $("a.profile-refresh").on("click", function(e) {
        var link = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
          method: "GET",
          url: link.attr("href"),
          beforeSend: function(xhr) {
            link.addClass("disabled").find("i").addClass("fa-spin");
          }
        }).done(function(data) {
          link.find("i").removeClass("fa-spin");
          $("#refresh-message").alert().show();
          $("#refresh-message").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });
      $("a.profile-flush").on("click", function(e) {
        var link = $(this);

        e.stopPropagation();
        e.preventDefault();
        $.ajax({
            method: "GET",
            url: $(this).attr("href"),
            beforeSend: function(xhr) {
              link.addClass("disabled").find("i").addClass("fa-spin");
            }
        }).done(function(data) {
          link.find("i").removeClass("fa-spin");
          $("#flush-message").alert().show();
          $("#flush-message").on("closed.bs.alert", function () {
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
          button.find("i").removeClass("fa-spin");
          $(".alert").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });
      $("a.dataset-refresh").on("click", function(e) {
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
          button.find("i").removeClass("fa-spin");
          $(".alert-gbif").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });
      $("a.dataset-frictionless").on("click", function(e) {
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
          button.find("i").removeClass("fa-spin");
          $(".alert-frictionless").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });
      $("a.article-process").on("click", function(e) {
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
          button.find("i").removeClass("fa-spin");
          $(".alert-article-process").alert().show();
          $(".alert").on("closed.bs.alert", function () {
            location.reload();
          });
        });
        return false;
      });
    },
    candidate_counter: function() {
      var self = this, slug = "";
      if (self.path === "/profile") {
        slug = self.path;
      } else if (self.path === "/admin" && self.identifier) {
        slug = self.path + "/user/" + self.identifier;
      } else if (self.path === "/help-others" && self.identifier) {
        slug = self.path + "/" + self.identifier;
      }
      if (slug.length > 0) {
        $.ajax({
          method: "GET",
          url: slug + "/candidate-count.json"
        }).done(function(data) {
          if (data.count > 0 && data.count <= 50) {
            $("#specimen-counter").text(data.count).show();
          } else if (data.count > 50) {
            $("#specimen-counter").text("50+").show();
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
