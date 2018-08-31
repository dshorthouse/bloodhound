/*global jQuery, window, document, self, encodeURIComponent, google, Bloodhound */
var Candidates = (function($, window) {

  "use strict";

  var _private = {

    data_sources: { agent : {}, taxon : {} },
    map: {},
    layer: {},

    init: function() {
      this.bloodhound();
      this.typeahead();
      this.activate_toggles();
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
    getParameterByName: function(name) {
        name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
        var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"),
            results = regex.exec(window.location.search);
        return results === null ? "" : decodeURIComponent(results[1].replace(/\+/g, " "));
    },
    dropdown_selected: function(){
      window.location.href = '/?q='+encodeURIComponent($(this).val());
    },
    activate_toggles: function(){
      $('input.toggle').change(function() {
          var id = $(this).attr("data-id");
          if($(this).attr("name") === "selection-all") {
              $.ajax({
                  method: "POST",
                  url: "/user-occurrence/bulk.json",
                  dataType: "json",
                  data: JSON.stringify({ ids: id })
              }).done(function(data) {
                  $('.table tbody tr').fadeOut(1000, function() {
                    $(this).remove();
                  });
              });
          } else {
              $(this).parent().parent().parent().fadeOut(1000, function() {
                  var row = $(this);
                  $.ajax({
                      method: "POST",
                      url: "/user-occurrence/" + id + ".json"
                  }).done(function(data) {
                      row.remove();
                  });
              });
          }
      });
    }
  };

  return {
    init: function() {
      _private.init();
    }
  };

}(jQuery, window));
