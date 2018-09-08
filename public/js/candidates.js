/*global jQuery, window, document, self, encodeURIComponent, google, Bloodhound */
var Candidates = (function($, window) {

  "use strict";

  var _private = {

    data_sources: { agent : {} },

    init: function() {
      this.bloodhound();
      this.typeahead();
      this.activate_radios();
    },
    bloodhound: function() {
      this.data_sources.agent = this.create_bloodhound('agent');
      this.data_sources.agent.initialize();
    },
    create_bloodhound: function(type) {
      return new Bloodhound({
        datumTokenizer : Bloodhound.tokenizers.whitespace,
        queryTokenizer : Bloodhound.tokenizers.whitespace,
        sufficient : 10,
        remote : {
          url : '/'+type+'.json?q=%QUERY',
          wildcard : '%QUERY',
          transform : function(r) { return $.map(r, function(v) { v['type'] = type; return v; });  }
        }
      });
    },
    typeahead: function(){
      $('#typeahead').typeahead({
          minLength: 3,
          highlight: true
        },
        {
          name: 'agent',
          source : this.data_sources.agent.ttAdapter(),
          display : 'name'
        }
        ).on('typeahead:select', function(obj, datum) {
          window.location.href = '/candidates/agent/' + datum.id;
        });
    },
    activate_radios: function(){
      $('input.specimen-selector').change(function() {
        var id = $(this).attr("data-id"),
            action = $(this).attr("data-action"),
            input = $(this);
        if($(this).attr("name") === "selection-all") {
            $.ajax({
                method: "POST",
                url: "/user-occurrence/bulk.json",
                dataType: "json",
                data: JSON.stringify({ ids: id, action: action })
            }).done(function(data) {
                $('.table tbody tr').fadeOut(500, function() {
                  $(this).remove();
                });
            });
        } else {
          $.ajax({
              method: "POST",
              url: "/user-occurrence/" + id + ".json",
              dataType: "json",
              data: JSON.stringify({ action: action })
          }).done(function(data) {
            input.parents("tr").fadeOut(500, function() {
              $(this).remove();
            });
          });
        }
      });
      $('button.remove').on('click', function() {
          var id = $(this).attr("data-id"),
              row = $(this).parents("tr");
          $.ajax({
              method: "POST",
              url: "/user-occurrence/" + id + ".json",
              dataType: "json",
              data: JSON.stringify({ visible: false})
          }).done(function(data) {
              row.fadeOut(500, function() {
                  $(this).remove();
              });
          });
      });
    }
  };

  return {
    init: function() {
      _private.init();
    }
  };

}(jQuery, window));
