var initAlertShown = true;
var map;
var bathyGoogle;
var bathyEsri;
var bathyBlueMarble;
var activeLayersStore = new Ext.data.ArrayStore({
  fields : ['switchViz','bbox','toTop','remove','name','getCaps','getCapsCached','legend']
});
var getCapsLinks = {};
var demoGetCapsLinks = {};
var activityStore = new Ext.data.ArrayStore({
  fields : ['i','type','request','response']
});
var cacheSearchStore;
var checkGetCapsStatusTimer;
var mapWin;
var proj4326   = new OpenLayers.Projection("EPSG:4326");
var proj900913 = new OpenLayers.Projection("EPSG:900913");
var proj3857   = new OpenLayers.Projection("EPSG:3857");

var dNow = new Date();
dNow.setMinutes(0);
dNow.setSeconds(0);
var dNow12Hours = new Date(dNow.getTime());
dNow12Hours.setHours(12);
var numTics = 4; // must be even!
var availableTimes = [];
for (var i = -numTics; i <= numTics; i++) {
  availableTimes.push(new Date(dNow12Hours.getTime() + 12 * i * 60 * 60 * 1000));
}
if (dNow.getHours() >= 12) {
  dNow.setHours(12);
}
else {
  dNow.setHours(0);
}

function init() {
  Ext.QuickTips.init();

  var loadingMask = Ext.get('loading-mask');
  var loading = Ext.get('loading');

  //Hide loading message
  loading.fadeOut({duration : 0.2,remove : true});

  //Hide loading mask
  loadingMask.setOpacity(0.9);
  loadingMask.shift({
     xy       : loading.getXY()
    ,width    : loading.getWidth()
    ,height   : loading.getHeight()
    ,remove   : true
    ,duration : 1
    ,opacity  : 0.1
    ,easing   : 'bounceOut'
  });

  function extractCallback(u,r) {
    // log activity
    activityStore.insert(0,new activityStore.recordType({
       i        : activityStore.getCount()
      ,type     : 'extract.json'
      ,request  : 'http://ogc-staging.herokuapp.com/wms/extract.json'
        + '?url=' + encodeURIComponent(u)
      ,response : r.responseText == '' ? 'ERROR' : 'OK'
    }));
    var el = document.getElementById(u);
    if (el) {
      el.removeChild(el.getElementsByTagName('img')[0]);
    }
    if (!el || r.responseText == '') {
      return; 
    }
    var json  = new OpenLayers.Format.JSON().read(r.responseText);
    var table = document.createElement('table');
    var tbody = document.createElement('tbody');
    for (var i = 0; i < json.length; i++ ) {
      if (!getCapsLinks[json[i]]) {
        getCapsLinks[json[i]] = false;
      }
      var tr = document.createElement('tr');
      var td = document.createElement('td');
      var a = document.createElement('a');
      a.href = 'javascript:getCaps("' + json[i] + '")';
      var img = new Image();
      img.src = 'img/folder.png';
      img.title = 'View all layers from this set';
      img.name = json[i];
      if (document.all) {
        // stupid IE
        img = document.createElement("<img src='img/folder.png' title='View all layers from this set' name='" + json[i] + "'>");
      }
      a.appendChild(img);
      td.appendChild(a);
      tr.appendChild(td);
      td = document.createElement('td');
      a = document.createElement('a');
      a.href = 'javascript:getCaps("' + json[i] + '")';
      a.innerHTML = json[i].length > 50 ? json[i].substr(0,50) + '...' : json[i];
      a.title = 'View all layers from this set';
      td.appendChild(a);
      tr.appendChild(td);
      tbody.appendChild(tr);
    }
    table.appendChild(tbody);
    el.appendChild(table);
  }

  var googleSearchPageLimit = 10;
  var googleSearchStore = new Ext.data.JsonStore({
     url           : 'proxy.php'
    ,root          : 'items'
    ,totalProperty : 'queries.request[0].totalResults'
    ,idProperty    : 'title'
    ,remoteSort    : true
    ,fields        : [
       'title'
      ,'link'
      ,'displayLink'
      ,'snippet'
    ]
    ,baseParams    : {start : 1}
    ,listeners     : {
      loadexception : function() {
        Ext.getCmp('googleSearchPanel').getEl().unmask();
      }
      ,beforeload : function(sto) {
        // only save known getcaps
        var saveGetCapsLinks = demoGetCapsLinks;
        for (var i in getCapsLinks) {
          if (getCapsLinks[i]) {
            saveGetCapsLinks[i] = true;
          }
        }
        getCapsLinks = saveGetCapsLinks;
        Ext.getCmp('googleSearchPanel').getEl().mask();
        sto.removeAll();
        var q = sto.baseParams.query;
        if (Ext.getCmp('wmsOnly').checked) {
          q += ' wms getcapabilities';
        }
        q = q.replace(/ /g,'%20');
        sto.setBaseParam('u','https://www.googleapis.com/customsearch/v1?key=AIzaSyAaEv39VgrcSNx57xhfm-HWKICvt2yF_PY&cx=001601573511269779126:csdoo9kvazg'
          + '&q='     + q + '%20-filetype:pdf%20-filetype:doc%20-filetype:xls'
          + '&start=' + sto.baseParams.start
          + '&limit=' + googleSearchPageLimit
        );
      }
      ,load : function(sto) {
        Ext.getCmp('googleSearchPanel').getEl().unmask();
        sto.each(function(rec) {
          OpenLayers.Request.issue({
             method   : 'POST'
            ,url      : 'proxy.php'
            ,headers  : {'Content-Type' : 'application/x-www-form-urlencoded'}
            ,data     : OpenLayers.Util.getParameterString({
              u : 'http://ogc-staging.herokuapp.com/wms/extract.json'
                + '?url=' + rec.get('link')
            })
            ,callback : OpenLayers.Function.bind(extractCallback,null,rec.get('link'))
          });
        });
      }
    }
  });

  var cacheSearchPageLimit = 10;
  cacheSearchStore = new Ext.data.JsonStore({
     url           : 'proxy.php'
    ,root          : 'data'
    ,totalProperty : 'records'
    ,idProperty    : '_id'
    ,remoteSort    : true
    ,fields        : [
       '_id'
      ,'abstract'
      ,'title'
      ,'name'
      ,'bbox'
      ,'wms_styles_json'
      ,{mapping : 'wms_server.url'         ,name : 'url'}
      ,{mapping : 'web_mapping_projections',name : 'projections'}
      ,{mapping : 'wms_server.map_formats' ,name : 'formats'}
      ,{mapping : 'wms_server.exceptions'  ,name : 'exceptions'}
    ]
    ,baseParams    : {page : 1}
    ,listeners     : {
      loadexception : function() {
        Ext.getCmp('cacheSearchPanel').getEl().unmask();
      }
      ,beforeload : function(sto) {
        Ext.getCmp('cacheSearchPanel').getEl().mask();
        sto.removeAll();
        sto.setBaseParam('u','http://ogc-staging.herokuapp.com/wms/search.json'
          + '?terms=' + googleSearchStore.baseParams.query
          + '&page=' + cacheSearchStore.baseParams.page
        );
      }
      ,load : function(sto) {
        Ext.getCmp('cacheSearchPanel').getEl().unmask();
        // log activity
        activityStore.insert(0,new activityStore.recordType({
           i        : activityStore.getCount()
          ,type     : 'search.json'
          ,request  : sto.baseParams.u
          ,response : 'n/a'
        }));
        checkGetCapsStatus();
        checkGetCapsStatusTimer = setTimeout('checkGetCapsStatus()',10000);
      }
    }
  });

  var searchField = new Ext.ux.form.SearchField({
     store     : googleSearchStore
    ,id        : 'searchField'
    ,width     : 320
    ,emptyText : 'Enter search term(s)'
  });

  // override trigger2 so that it fires cacheSearch
  searchField.onTrigger2Click = function() {
    var v = this.getRawValue();
    if (v.length < 1){
    this.onTrigger1Click();
      return;
    }
    var o = {start: 0};
    this.store.baseParams = this.store.baseParams || {};
    this.store.baseParams[this.paramName] = v;
    this.store.reload({params:o});
    this.hasSearch = true;
    this.triggers[0].show();
    cacheSearchStore.load();
  }

  var searchWin = new Ext.Window({
     title       : 'OGC-Search'
    ,x           : 0
    ,y           : 0
    ,layout      : 'border'
    ,closable    : false
    ,width       : 600
    ,minWidth    : 600
    ,height      : 300
    ,bodyStyle   : 'background:white'
    ,constrainHeader : true
    ,listeners   : {resize : function(win,w,h) {
      if (Ext.getCmp('searchField')) {
        Ext.getCmp('searchField').setWidth(w - 145);
      }
    }}
    ,items       : [
      new Ext.Panel({
         layout    : 'fit'
        ,id        : 'googleSearchPanel'
        ,region    : 'center'
        ,split     : true
        ,bodyStyle : 'background:white'
        ,border    : false
        ,style     : {
          borderRight : '1px solid #99BBE8'
        }
        ,tbar      : [
           '<span style="color:#15428B;font:bold 11px tahoma,arial,verdana,sans-serif">Google results</span>'
          ,{icon : 'img/blank.png'} // for spacing
          ,'->'
          ,'Restrict results to WMS GetCapabilities listings?'
          ,' '
          ,new Ext.form.Checkbox({
             checked : true
            ,id      : 'wmsOnly'
          })
        ]
        ,bbar      : new Ext.PagingToolbar({
           pageSize     : googleSearchPageLimit
          ,store        : googleSearchStore
          ,displayInfo  : true
          ,displayMsg   : 'Displaying results {0} - {1} of {2}'
          ,emptyMsg     : 'No results to display'
          ,listeners    : {beforechange : function(tbar,params) {
            googleSearchStore.setBaseParam('start',params.start + 1);
          }}
        })
        ,items     : [
          new Ext.DataView({
             tpl          :  new Ext.XTemplate(
               '<tpl for=".">'
              ,'<div class="search-item">'
                ,'<a target=_blank href="{link}" title="View original webpage data source">{title}</a><br><span class="displayLink">{displayLink}</span><br>{snippet}<br><div id="{link}"><img src="img/loading.gif"></div>'
              ,'</div></tpl>'
            )
            ,store        : googleSearchStore
            ,itemSelector : 'div.search-item'
            ,autoScroll   : true
          })
        ]
      })
      ,new Ext.Panel({
         width  : 250
        ,id     : 'cacheSearchPanel'
        ,region : 'east'
        ,split  : true
        ,border : false
        ,layout : 'fit'
        ,style  : {
          borderLeft : '1px solid #99BBE8'
        }
        ,tbar   : [
           '<span style="color:#15428B;font:bold 11px tahoma,arial,verdana,sans-serif">OGC-Search results</span>'
          ,{icon : 'img/blank.png'} // for spacing
          ,'->'
          ,{
             text           : 'Auto synchronize'
            ,id             : 'autoSyncButton'
            ,icon           : 'img/arrow_refresh.png'
            ,allowDepressed : true
            ,enableToggle   : true
            ,pressed        : true 
            ,handler        : function(but) {
              if (but.pressed) {
                checkGetCapsStatus();
                checkGetCapsStatusTimer = setTimeout('checkGetCapsStatus()',10000);
              }
              else {
                clearTimeout(checkGetCapsStatusTimer);
              }
            }
          }
          ,{
             text           : 'Activity log'
            ,id             : 'activityLogButton'
            ,icon           : 'img/application_view_columns.png'
            ,allowDepressed : true
            ,enableToggle   : true
            ,handler        : function(but) {
              if (but.pressed && !Ext.getCmp('activityLog')) {
                var win = new Ext.Window({
                   id     : 'activityLog'
                  ,title  : 'Activity log'
                  ,layout : 'fit'
                  ,width  : 640
                  ,height : 480
                  ,constrainHeader : true
                  ,tbar   : [
                    {
                       text    : 'Clear log'
                      ,icon    : 'img/bin.png'
                      ,handler : function() {activityStore.removeAll()}
                    }
                    ,'->'
                    ,{
                       text         : 'Keep on top'
                      ,id           : 'activityKeepOnTop'
                      ,icon         : 'img/shape_move_front.png'
                      ,allowDepress : true
                      ,enableToggle : true
                      ,pressed      : true
                    }
                  ]
                  ,items  : new Ext.grid.GridPanel({
                     border  : false
                    ,store   : activityStore
                    ,autoExpandColumn : 'request'
                    ,columns : [
                       {dataIndex : 'i'                           ,sortable : true,align : 'center',width : 75}
                      ,{dataIndex : 'type'    ,header : 'Type'    ,sortable : true,align : 'center'}
                      ,{dataIndex : 'request' ,header : 'Request' ,sortable : true,id : 'request',renderer : renderLink}
                      ,{dataIndex : 'response',header : 'Response',sortable : true}
                    ]
                  })
                  ,listeners : {
                    close : function() {
                      but.toggle(false,true);
                    }
                  }
                });
                win.on('deactivate',function(win) {
                  if (Ext.getCmp('activityKeepOnTop').pressed) {
                    win.toFront();
                  }
                },this,{delay : 1});
                win.show();
              }
              else {
                if (Ext.getCmp('activityLog')) {
                  Ext.getCmp('activityLog').close();
                }
              }
            }
          }
          ,'-'
          ,'<span style="color:#aaaaaa">Restrict results to map boundaries?</span>'
          ,' '
          ,new Ext.form.Checkbox({
             checked    : false
            ,id         : 'restrictToBbox'
            ,disabled   : true
            ,listeners  : {
              check : function() {
              }
            }
          })
        ]
        ,bbar      : new Ext.PagingToolbar({
           pageSize     : cacheSearchPageLimit
          ,store        : cacheSearchStore
          ,displayInfo  : true
          ,displayMsg   : 'Displaying results {0} - {1} of {2}'
          ,emptyMsg     : 'No results to display'
          ,listeners    : {beforechange : function(tbar,params) {
            cacheSearchStore.setBaseParam('page',(params.start + 1) / cacheSearchPageLimit);
          }}
        })
        ,items     : [
          new Ext.DataView({
             tpl          :  new Ext.XTemplate(
               '<tpl for=".">'
              ,'<div class="search-item">'
                ,'<table id="cacheResultsHeader"><tr><td><a href="javascript:addWMS(\'{_id}\')"><img src="img/map_add.png" title="Add layer to map"></a></td><td><a title="Add layer to map" href="javascript:addWMS(\'{_id}\')">{title}</a></td></tr></table><span class="displayLink">{[values.url.replace("http://","").split("?")[0]]}</span><br>{[values.abstract != "" ? values.abstract + "<br>" : ""]}'
//                ,'<tpl for="wms_styles_json">{[values.legend_url ? "<img height=40 src=\'" + values.legend_url + "\'>&nbsp;&nbsp;" : ""]}</tpl>'
              ,'</div></tpl>'
            )
            ,store        : cacheSearchStore
            ,itemSelector : 'div.search-item'
            ,autoScroll   : true
          })
        ]
      })
    ]
    ,tbar : [
       searchField
      ,'->'
      ,new Ext.Toolbar.Button({
         text : 'Favorite searches'
        ,icon : 'img/thumb_up.png'
        ,menu : [
           {text : 'climate',handler : function() {Ext.getCmp('searchField').setValue('climate');Ext.getCmp('searchField').onTrigger2Click()}}
          ,{text : 'hurricane',handler : function() {Ext.getCmp('searchField').setValue('hurricane');Ext.getCmp('searchField').onTrigger2Click()}}
          ,{text : 'ocean',handler : function() {Ext.getCmp('searchField').setValue('ocean');Ext.getCmp('searchField').onTrigger2Click()}}
          ,{text : 'salt',handler : function() {Ext.getCmp('searchField').setValue('salt');Ext.getCmp('searchField').onTrigger2Click()}}
          ,{text : 'temperature',handler : function() {Ext.getCmp('searchField').setValue('temperature');Ext.getCmp('searchField').onTrigger2Click()}}
        ]
      })
    ]
  });
  searchWin.show();

  var baseLayersStore = new Ext.data.ArrayStore({
     fields : ['name','value']
    ,data   : [
       ['ESRI Ocean (EPSG:900913)'      ,'bathyEsri']
      ,['Google Satellite (EPSG:900913)','bathyGoogle']
      ,['Blue Marble (EPSG:4326)'       ,'bathyBlueMarble']
    ] 
  });

  mapWin = new Ext.Window({
     title     : 'Map'
    ,layout    : 'fit'
    ,width     : 450
    ,minWidth  : 450
    ,height    : 480
    ,closable  : false
    ,constrainHeader : true
    ,html      : '<div id="map"></div><div id="timeSlider"></div></div>'
    ,listeners : {
      afterrender : function(w) {
        initMap();
        Ext.getCmp('timeSlider').setWidth(w.getInnerWidth() - 75);
        Ext.getCmp('sliderTics').setWidth(w.getInnerWidth() - 48);
      }
      ,bodyresize : function(p,w,h) {
        var el = document.getElementById('map');
        if (el && map) {
          el.style.width = w;
          el.style.height = h;
          map.updateSize();
          Ext.getCmp('timeSlider').setWidth(w - 75);
          Ext.getCmp('sliderTics').setWidth(w - 48);
        }
      }
    }
    ,tbar      : [
       {icon : 'img/blank.png'} // for spacing
      ,'->'
      ,'Base layer: '
      ,' '
      ,new Ext.form.ComboBox({
         store          : baseLayersStore
        ,displayField   : 'name'
        ,valueField     : 'value'
        ,value          : 'bathyEsri'
        ,editable       : false
        ,triggerAction  : 'all'
        ,mode           : 'local'
        ,width          : 190
        ,forceSelection : true
        ,listeners      : {
          select : function(comboBox,rec) {
            bathyEsri.setVisibility(rec.get('value') == 'bathyEsri');
            if (rec.get('value') == 'bathyEsri' || rec.get('value') == 'bathyGoogle') {
              if (map.baseLayer.name != 'Google Satellite (EPSG:900913)') {
                map.setBaseLayer(bathyGoogle);
                map.zoomToMaxExtent();
              }
            }
            else {
              map.setBaseLayer(bathyBlueMarble);
              map.zoomToMaxExtent();
            }
          }
        }
      })
    ]
    ,bbar      : {
       xtype    : 'container'
      ,height   : 42
      ,defaults : {border : false,bodyStyle : 'background:transparent'}
      ,cls      : 'x-toolbar'
      ,id      : 'timeSliderContainer'
      ,items : [
         new Ext.Panel({
           width       : 100
          ,height      : 15
          ,id          : 'sliderTics'
          ,html        : '<table id="sliderTicsTable"><tbody></tbody></table>'
          ,listeners   : {afterrender : function() {
            var tbody = document.getElementById('sliderTicsTable').getElementsByTagName('tbody')[0];
            var tr = document.createElement('tr');
            for (var i = 0; i < availableTimes.length; i++) {
              var td = document.createElement('td');
              if (availableTimes[i].getHours() == 0) {
                td.innerHTML = (availableTimes[i].getMonth() + 1) + '/' + availableTimes[i].getDate();
                td.style.width = (1 / numTics * 100) + '%';
                td.style.paddingRight = i;
              }
              else {
                td.innerHTML = '<img src="img/blank.png" width=2>';
              }
              if (i == 0 || availableTimes[i].getHours() != 0 || i == availableTimes.length - 1) {
                td.className = 'fillSolid';
              }
              tr.appendChild(td);
              if (availableTimes[i].getTime() == dNow.getTime()) {
                Ext.getCmp('timeSlider').setValue(i);
              }
            }
            tbody.appendChild(tr);
          }}
        })
        ,new Ext.Panel({
           layout       : 'column'
          ,defaults     : {border : false,bodyStyle : 'background:transparent'}
          ,items        : [
            {html : '&nbsp;',width : 5}
            ,new Ext.Button({
               icon : 'img/control_rewind_blue.png'
              ,handler : function() {
                var slider = Ext.getCmp('timeSlider');
                slider.setValue(slider.getValue() - 1);
              }
            })
            ,{html : '&nbsp;&nbsp;',width : 5}
            ,new Ext.Slider({
               increment   : 1
              ,minValue    : 0
              ,maxValue    : availableTimes.length - 1
              ,width       : 100
              ,id          : 'timeSlider'
              ,listeners   : {change : function(slider,val) {
                var dStr = availableTimes[val].getUTCFullYear() + '-' + String.leftPad(availableTimes[val].getUTCMonth() + 1,2,'0') + '-' + String.leftPad(availableTimes[val].getUTCDate(),2,'0') + 'T' + String.leftPad(availableTimes[val].getUTCHours(),2,'0') + ':00';
                for (var i = 0; i < map.layers.length; i++) {
                  // WMS layers only
                  if (map.layers[i].DEFAULT_PARAMS) {
                    map.layers[i].mergeNewParams({TIME : dStr});
                  }
                }
              }}
            })
            ,{html : '&nbsp;&nbsp;',width : 5}
            ,new Ext.Button({
               icon    : 'img/control_fastforward_blue.png'
              ,handler : function() {
                var slider = Ext.getCmp('timeSlider');
                slider.setValue(slider.getValue() + 1);
              }
            })
            ,{html : '&nbsp;',width : 5}
          ]
        })
      ]
    }
  });

  var activeLayersWin = new Ext.Window({
     title       : 'Active layers'
    ,layout      : 'fit'
    ,width       : 425
    ,minWidth    : 425
    ,height      : 250
    ,autoScroll  : true
    ,bodyStyle   : 'background:white'
    ,constrainHeader : true
    ,closable    : false
    ,listeners   : {resize : function(win,w,h) {
      if (Ext.getCmp('getCapsField')) {
        Ext.getCmp('getCapsField').setWidth(w - 145 - 80);
      }
    }}
    ,tbar        : [
      new Ext.form.TextField({
         width     : 200
        ,id        : 'getCapsField'
        ,emptyText : 'Optional: enter a WMS GetCaps URL'
        ,listeners : {specialkey : function(f,e) {
          if (e.getKey() == e.ENTER) {
            getCaps(f.getValue());
          }
        }}
      })
      ,' '
      ,new Ext.Toolbar.Button({
         text : 'Favorite GetCaps'
        ,icon : 'img/thumb_up.png'
        ,menu : [
           {text : 'ASA ECOP :: near real time ocean layers with time support',handler : function() {var url = 'http://services.asascience.com/ecop/wms.aspx?REQUEST=GetCapabilities&VERSION=1.1.1&SERVICE=WMS';Ext.getCmp('getCapsField').setValue(url);getCaps(url)}}
          ,{text : 'MARACOOS :: near real time ocean layers with time support',handler : function() {var url = 'http://tds.maracoos.org/ncWMS/wms?REQUEST=GetCapabilities&VERSION=1.1.1&SERVICE=WMS';Ext.getCmp('getCapsField').setValue(url);getCaps(url)}}
          ,{text : 'NHC :: near real time hurricane-related layers',handler : function() {var url = 'http://nowcoast.noaa.gov/wms/com.esri.wms.Esrimap/wwa?service=wms&version=1.1.1&request=GetCapabilities';Ext.getCmp('getCapsField').setValue(url);getCaps(url)}}
        ]
      })
      ,'->'
      ,{
         text    : 'Remove all'
        ,icon    : 'img/trash-icon.png'
        ,handler : function() {
          var l = [];
          for (var i = 0; i < map.layers.length; i++) {
            if (!map.layers[i].isBaseLayer && map.layers[i].name != 'ESRI Ocean (EPSG:900913)') {
              l.push(map.layers[i]);
            }
          }
          for (var i = 0; i < l.length; i++) {
            map.removeLayer(l[i]);
          }
        }
      }
    ]
    ,items       : [
      new Ext.grid.GridPanel({
         border  : false
        ,store   : activeLayersStore
        ,autoExpandColumn : 'name'
        ,hideHeaders      : true
        ,disableSelection : true
        ,columns : [
           {dataIndex : 'switchViz',renderer : renderLayerVisibility,width : 30,align : 'center'}
          ,{dataIndex : 'bbox'     ,renderer : renderLayerBbox      ,width : 30,align : 'center'}
          ,{dataIndex : 'toTop'    ,renderer : renderLayerToTop     ,width : 30,align : 'center'}
          ,{dataIndex : 'getCaps'  ,renderer : renderLayerGetCaps   ,width : 30,align : 'center'}
          ,{dataIndex : 'legend'   ,renderer : renderLayerLegend    ,width : 30,align : 'center'}
          ,{dataIndex : 'settings' ,renderer : renderSettings       ,width : 30,align : 'center'}
          ,{dataIndex : 'image'    ,renderer : renderLayerImage     ,width : 30,align : 'center'}
          ,{dataIndex : 'name'     ,id : 'name'}
          ,{dataIndex : 'remove'   ,renderer : renderLayerRemove    ,width : 30,align : 'center'}
        ]
      })
    ]
  });
  if (getVPSize()[0] - 10 >= searchWin.minWidth) {
    searchWin.setWidth(getVPSize()[0] - 10);
  }
  Ext.getCmp('cacheSearchPanel').setWidth(searchWin.getWidth() / 2);
  mapWin.setPosition(0,searchWin.height + 1);
  if (getVPSize()[0] / 2 >= mapWin.minWidth) {
    mapWin.setSize(getVPSize()[0] / 2,getVPSize()[1] - searchWin.height - 8);
  }
  mapWin.show();
  activeLayersWin.setPosition(mapWin.width + 1,mapWin.y);
  if (getVPSize()[0] - mapWin.width - 11 >= activeLayersWin.minWidth) {
    activeLayersWin.setSize(getVPSize()[0] - mapWin.width - 11,mapWin.height);
  }
  activeLayersWin.show();
}

function initMap() {
  // set transformation functions from/to alias projection
  OpenLayers.Projection.addTransform("EPSG:4326","EPSG:3857",OpenLayers.Layer.SphericalMercator.projectForward);
  OpenLayers.Projection.addTransform("EPSG:3857","EPSG:4326",OpenLayers.Layer.SphericalMercator.projectInverse);

  OpenLayers.Util.onImageLoadError = function() {this.src = 'img/blank.png';}

  map = new OpenLayers.Map('map',{
     projection        : proj900913
    ,displayProjection : proj4326
    ,units             : 'm'
    ,maxExtent         : new OpenLayers.Bounds(-20037508,-20037508,20037508,20037508.34)
  });

  var navControl = new OpenLayers.Control.NavToolbar();
  map.addControl(navControl);

  var mouseControl = new OpenLayers.Control.MousePosition({
    formatOutput: function(lonLat) {
      return convertDMS(lonLat.lat.toFixed(5), "LAT") + ' ' + convertDMS(lonLat.lon.toFixed(5), "LON");
    }
  });
  mouseControl.displayProjection = new OpenLayers.Projection('EPSG:4326');
  map.addControl(mouseControl);

  bathyGoogle = new OpenLayers.Layer.Google(
     'Google Satellite (EPSG:900913)'
    ,{
       type              : google.maps.MapTypeId.SATELLITE
      ,projection        : proj900913
      ,sphericalMercator : true
      ,wrapDateLine      : true
    }
  );
  map.addLayer(bathyGoogle);

  bathyEsri = new OpenLayers.Layer.XYZ(
     'ESRI Ocean (EPSG:900913)'
    ,'http://services.arcgisonline.com/ArcGIS/rest/services/Ocean_Basemap/MapServer/tile/${z}/${y}/${x}.jpg'
    ,{
       sphericalMercator : true
      ,isBaseLayer       : false
      ,wrapDateLine      : true
    }
  );
  map.addLayer(bathyEsri);

  bathyBlueMarble = new OpenLayers.Layer.WMS(
     'Blue Marble (EPSG:4326)'
    ,'http://asascience.mine.nu:8080/geoserver/gwc/service/wms?&TILED=YES'
    ,{
      layers : 'base:BlueMarble'
    }
    ,{
       isBaseLayer   : true
      ,projection    : proj4326
      ,maxResolution : 1.40625
      ,maxExtent     : new OpenLayers.Bounds(-180,-90,180,90)
      ,visibility    : false
      ,wrapDateLine  : true
    }
  );
  map.addLayer(bathyBlueMarble);

  map.setCenter(new OpenLayers.LonLat(-53,25).transform(proj4326,proj900913),3);

  map.events.register('moveend',this,function() {
    if (navControl.controls[1].active) {
      navControl.controls[1].deactivate();
      navControl.draw();
    }
  });

  map.events.register('preaddlayer',this,function(e) {
    var l = map.getLayersByName(e.layer.name);
    if (l.length > 0) {
      Ext.Msg.alert('Add layer error','A layer with this name has already been mapped.');
      return false;
    }
    var projOK = (map.getProjection().toLowerCase() == 'epsg:900913' || map.getProjection().toLowerCase() == 'epsg:3857')
        && (String(e.layer.options.projection).toLowerCase() == 'epsg:900913' || String(e.layer.options.projection).toLowerCase() == 'epsg:3857')
    var projAlternates = [];
    for (var i = 0; i < e.layer.options.srs.length; i++) {
      projOK = projOK || (e.layer.options.srs[i].toLowerCase() == map.getProjection().toLowerCase());
      if (e.layer.options.srs[i].toLowerCase() == 'epsg:900913' || e.layer.options.srs[i].toLowerCase() == 'epsg:3857') {
        projAlternates.push(e.layer.options.srs[i].toUpperCase());
      }
    }
    if (!projOK) {
      var msg = 'This layer does not appear to support the current base layer\'s projection.  The layer will be added to the map, but it might not be visible.';
      if ((map.getProjection().toLowerCase() == 'epsg:900913' || map.getProjection().toLowerCase() == 'epsg:3857') && projAlternates.length > 0) {
        msg += ' The layer appears to support ' + projAlternates.join(' and ') + ' which would work with the current map projection.  Experiment with the projection option by clicking on the settings icon to the left of the layer name in the active layers list.';
      }
      Ext.Msg.alert('Add layer warning',msg);
    }
  });

  map.events.register('addlayer',this,function(e) {
    e.layer.events.register('loadstart',this,function(e) {
      var idx = activeLayersStore.find('name',e.object.name);
      if (idx >= 0 && e.object.visibility) {
        var rec = activeLayersStore.getAt(idx);
        rec.set('switchViz','loading');
        rec.commit();
      }
    });
    e.layer.events.register('loadend',this,function(e) {
      var idx = activeLayersStore.find('name',e.object.name);
      if (idx >= 0) {
        var rec = activeLayersStore.getAt(idx);
        rec.set('switchViz',e.object.visibility ? 'off' : 'on');
        rec.commit();
      }
    });
    e.layer.events.register('visibilitychanged',this,function(e) {
      var idx = activeLayersStore.find('name',e.object.name);
      if (idx >= 0) {
        activeLayersStore.getAt(idx).set('switchViz',e.object.visibility ? 'off' : 'on');
        activeLayersStore.getAt(idx).commit();
      }
    });
    if (!getCapsLinks[e.layer.options.getcaps]) {
      getCapsLinks[e.layer.options.getcaps] = false;
    }
    activeLayersStore.insert(0,new activeLayersStore.recordType({
       name          : e.layer.name
      ,bbox          : e.layer.options.llbbox
      ,getCaps       : e.layer.options.getcaps
      ,getCapsCached : getCapsLinks[e.layer.options.getcaps]
    }));
  });

  map.events.register('removelayer',this,function(e) {
    var idx = activeLayersStore.find('name',e.layer.name);
    if (idx >= 0) {
      activeLayersStore.removeAt(idx);
    }
  });

  addDemoLyrs();
}

function getCaps(u) {
  if (!getCapsLinks[u]) {
    // register the url in the cache
    OpenLayers.Request.issue({
       method  : 'POST'
      ,url     : 'proxy.php'
      ,headers : {'Content-Type' : 'application/x-www-form-urlencoded'}
      ,data    : OpenLayers.Util.getParameterString({
        u : 'http://ogc-staging.herokuapp.com/wms/parse.json'
          + '?url=' + encodeURIComponent(u)
          + '&terms=' + Ext.getCmp('searchField').getValue()
      })
      ,callback : function(r) {
        // log activity
        var json = new OpenLayers.Format.JSON().read(r.responseText);
        activityStore.insert(0,new activityStore.recordType({
           i        : activityStore.getCount()
          ,type     : 'parse.json'
          ,request  : 'http://ogc-staging.herokuapp.com/wms/parse.json'
            + '?url=' + encodeURIComponent(u)
            + '&terms=' + Ext.getCmp('searchField').getValue()
          ,response : json.status
        }));
      }
    });
  }

  if (Ext.getCmp('getCaps')) {
    Ext.getCmp('getCaps').destroy();
  }
  if (!getCapsLinks[u]) {
    parseGetCapsLocally(u);
  }
  else {
    parseGetCapsFromCache(u);
  }
}

function renderLink(val) {
  return '<a target=_blank href="' + val + '">' + val + '</a>';
}

function renderLayerVisibility(val,metadata,rec) {
  if (!val || val == 'loading') {
    metadata.attr = 'ext:qtip="Loading..."';
    return '<img src="img/loading.gif" width=16 height=16>';
  }
  else {
    metadata.attr = 'ext:qtip="Turn layer ' + val + '"';
    return '<a href="javascript:toggleLayerVisibility(\'' + rec.get('name') + '\')"><img src="img/wms.' + val + '.png" width=16 height=16></a>';
  }
}

function renderLayerToTop(val,metadata,rec) {
  metadata.attr = 'ext:qtip="Move layer to top"';
  return '<a href="javascript:moveLayerToTop(\'' + rec.get('name') + '\')"><img src="img/move-top.png" width=16 height=16></a>';
}

function renderLayerGetCaps(val,metadata,rec) {
  metadata.attr = 'ext:qtip="View all layers from this set"';
  if (rec.get('getCapsCached')) {
    return '<a href="javascript:getCaps(\'' + val + '\')"><img src="img/folder_explore.png" width=16 height=16></a>';
  }
  else {
    return '<a href="javascript:getCaps(\'' + val + '\')"><img src="img/folder.png" width=16 height=16></a>';
  }
}

function renderLayerLegend(val,metadata,rec) {
  if (val == 'loading') {
    metadata.attr = 'ext:qtip="Loading..."';
    return '<img src="img/loading.gif" width=16 height=16>';
  }
  else {
    metadata.attr = 'ext:qtip="View layer legend"';
    return '<a id="legend.' + rec.get('name') + '" href="javascript:showLayerLegend(\'' + rec.get('name') + '\')"><img src="img/legend-icon.png" width=16 height=16></a>';
  }
}

function renderSettings(val,metadata,rec) {
  metadata.attr = 'ext:qtip="View layer options"';
  return '<a id="settings.' + rec.get('name') + '" href="javascript:showLayerSettings(\'' + rec.get('name') + '\')"><img src="img/Options.png" width=16 height=16></a>';
}

function renderLayerImage(val,metadata,rec) {
  var url = map.getLayersByName(rec.get('name'))[0].getFullRequestString({}) + '&bbox=' + map.getExtent().toArray() + '&width=' + mapWin.getInnerWidth() + '&height=' + mapWin.getInnerHeight();
  metadata.attr = 'ext:qtip="View this layer in a new window"';
  return '<a target=_blank href="' + url + '"><img src="img/map_go.png" width=16 height=16></a>';
}

function renderLayerRemove(val,metadata,rec) {
  metadata.attr = 'ext:qtip="Remove layer"';
  return '<a href="javascript:removeLayer(\'' + rec.get('name') + '\')"><img src="img/trash-icon.png" width=16 height=16></a>';
}

function renderLayerBbox(val,metadata,rec) {
  metadata.attr = 'ext:qtip="Zoom to layer"';
  return '<a href="javascript:zoomToBbox(\'' + val + '\')"><img src="img/Search.png" width=16 height=16></a>';
}

function toggleLayerVisibility(name) {
  map.getLayersByName(name)[0].setVisibility(!map.getLayersByName(name)[0].visibility);
}

function showLayerLegend(name) {
  var rec = activeLayersStore.getAt(activeLayersStore.find('name',name));
  rec.set('legend','loading');
  rec.commit();
  var img = new Image();
  img.onload = function() {
    rec.set('legend','');
    rec.commit();
    if (!Ext.getCmp('legend.popup.' + name)) {
      new Ext.Window({
         id        : 'legend.popup.' + name
        ,title     : name + ' :: legend'
        ,closable  : true
        ,items     : {border : false,bodyCssClass : 'popup',html : '<img id="legend.img.' + name + '" src="img/blank.png">'}
        ,constrainHeader : true
        ,listeners : {
          hide : function() {
            this.destroy();
          }
          ,afterrender : function() {
            document.getElementById('legend.img.' + name).src = img.src;
          }
        }
      }).show();
    }
  }
  img.onerror = function() {
    Ext.Msg.alert('Legend error','Unable to fetch a legend for this layer.');
    rec.set('legend','');
    rec.commit();
  }
  img.src = map.getLayersByName(name)[0].getFullRequestString({}).replace('GetMap','GetLegendGraphic').replace('LAYERS=','LAYER=');
}

function removeLayer(name) {
  map.removeLayer(map.getLayersByName(name)[0]);
}

function moveLayerToTop(name) {
  map.setLayerIndex(map.getLayersByName(name)[0],map.getNumLayers() - 1);
  var idx = activeLayersStore.find('name',name);
  if (idx >= 0) {
    var rec = activeLayersStore.getAt(idx);
    activeLayersStore.removeAt(idx);
    activeLayersStore.insert(0,rec);
  }
}

function zoomToBbox(bbox) {
  var p = bbox.split(',');
  map.zoomToExtent(new OpenLayers.Bounds(p[0],p[1],p[2],p[3]).transform(proj4326,map.getProjectionObject()));
}

function showLayerSettings(name) {
  var lyr = map.getLayersByName(name)[0];
  var height = 26;
  var items = [
    new Ext.Slider({
       fieldLabel : 'Opacity'
      ,id         : 'opacity.' + name
      ,width      : 130
      ,minValue   : 0
      ,maxValue   : 100
      ,value      : lyr.opacity ? lyr.opacity * 100 : 100
      ,plugins    : new Ext.slider.Tip({
        getText : function(thumb) {
          return String.format('<b>{0}%</b>', thumb.value);
        }
      })
      ,listeners  : {
        change : function(slider,val) {
          lyr.setOpacity(val / 100);
        }
      }
    })
  ];

  height += 27;
  items.push(
    new Ext.form.ComboBox({
       fieldLabel     : 'Single tile'
      ,store          : new Ext.data.ArrayStore({
         fields : ['name']
        ,data   : [['true'],['false']]
      })
      ,displayField   : 'name'
      ,valueField     : 'name'
      ,value          : lyr.options.singleTile
      ,editable       : false
      ,triggerAction  : 'all'
      ,mode           : 'local'
      ,width          : 130
      ,forceSelection : true
      ,listeners      : {
        select : function(comboBox,rec) {
          // can't dynamically change singleTile, so create a new layer to replace the existing one
          var lyrChanged =  new OpenLayers.Layer.WMS(
             lyr.name
            ,lyr.url
            ,{
               layers      : lyr.params.LAYERS
              ,transparent : true
            }
            ,{
               isBaseLayer   : false
              ,wrapDateLine  : true
              ,singleTile    : rec.get('name') == 'true'
              ,projection    : lyr.params.SRS
            }
          );
          lyrChanged.options.styles = lyr.options.styles;
          lyrChanged.mergeNewParams({STYLES : lyrChanged.options.styles[0]});
          lyrChanged.options.srs = lyr.options.srs;
          lyrChanged.options.llbbox = lyr.options.llbbox;
          lyrChanged.options.getcaps = lyr.options.getcaps;
          map.removeLayer(map.getLayersByName(name)[0]);
          map.addLayer(lyrChanged);
        }
      }
    })
  );

  if (lyr.options.styles.length > 0) {
    height += 27;
    var sto = new Ext.data.ArrayStore({
      fields : ['name']
    });
    for (var i = 0; i < lyr.options.styles.length; i++) {
      sto.add(new sto.recordType({
        name : lyr.options.styles[i]
      }));
    }
    items.push(
      new Ext.form.ComboBox({
         fieldLabel     : 'Style'
        ,store          : sto
        ,displayField   : 'name'
        ,valueField     : 'name'
        ,value          : lyr.params.STYLES
        ,editable       : false
        ,triggerAction  : 'all'
        ,mode           : 'local'
        ,width          : 130
        ,forceSelection : true
        ,listeners      : {
          select : function(comboBox,rec) {
            lyr.mergeNewParams({STYLES : rec.get('name'),PALETTE : rec.get('name').split('/')[1]});
          }
        }
      })
    );
  }

  if (lyr.options.srs.length > 0) {
    height += 27;
    var sto = new Ext.data.ArrayStore({
      fields : ['name']
    });
    for (var i = 0; i < lyr.options.srs.length; i++) {
      sto.add(new sto.recordType({
        name : lyr.options.srs[i]
      }));
    }
    items.push(
      new Ext.form.ComboBox({
         fieldLabel     : 'Projection'
        ,store          : sto
        ,displayField   : 'name'
        ,valueField     : 'name'
        ,value          : lyr.params.SRS
        ,editable       : false
        ,triggerAction  : 'all'
        ,mode           : 'local'
        ,width          : 130
        ,forceSelection : true
        ,listeners      : {
          select : function(comboBox,rec) {
            lyr.projection = new OpenLayers.Projection(rec.get('name'));
            lyr.mergeNewParams({SRS : rec.get('name')});
          }
        }
      })
    );
  }

  if (!Ext.getCmp('settings.popup.' + name)) {
    new Ext.ToolTip({
       id        : 'settings.popup.' + name
      ,title     : name + ' :: settings'
      ,anchor    : 'bottom'
      ,target    : 'settings.' + name
      ,autoHide  : false
      ,closable  : true
      ,items     : [
         new Ext.FormPanel({buttonAlign : 'center',border : false,bodyStyle : 'background:transparent',width : 240,height : height,labelWidth : 100,labelSeparator : '',items : items})
      ]
      ,listeners : {hide : function() {
        this.destroy();
      }}
    }).show();
  }
}

function addWMS(id) {
  var idx = cacheSearchStore.find('_id',id);
  if (idx >= 0) {
    var rec = cacheSearchStore.getAt(idx);
    var lyr =  new OpenLayers.Layer.WMS(
       rec.get('title')
      ,rec.get('url').split('?')[0]
      ,{
         layers      : rec.get('name')
        ,transparent : true
      }
      ,{
         isBaseLayer   : false
        ,wrapDateLine  : true
        ,singleTile    : false
      }
    );
    lyr.options.styles = [];
    Ext.each(rec.get('wms_styles_json'),function(s) {
      if (!lyr.options.styles) {
        lyr.options.styles = [];
      }
      lyr.options.styles.push(s.name);
    });
    lyr.mergeNewParams({STYLES : lyr.options.styles[0]});
    lyr.options.srs     = rec.get('projections') || [];
    lyr.options.llbbox  = new OpenLayers.Format.WKT().read(rec.get('bbox')).geometry.getBounds().toBBOX();
    lyr.options.getcaps = rec.get('url');
    map.addLayer(lyr);
  }
  else {
    Ext.Msg.alert('Add layer','There was an error accessing this layer.');
  }
}

function addDemoLyrs() {
  var demoLyrs = [
    {
       name       : 'WW3 Wave Period'
      ,url        : 'http://services.asascience.com/ecop/wms.aspx?'
      ,layers     : 'WW3_WAVE_HEIGHT'
      ,singleTile : true
      ,styles     : ['WAVE_HEIGHT_STYLE']
      ,srs        : ['EPSG:3857','EPSG:41001','EPSG:4326','MERCATOR']
      ,projection : 'EPSG:3857'
      ,llbbox     : '-180,-90,180,90'
      ,getcaps    : 'http://services.asascience.com/ecop/wms.aspx?REQUEST=GetCapabilities&VERSION=1.1.1&SERVICE=WMS'
    }
    ,{
       name       : 'Cone of Uncertainty'
      ,url        : 'http://nowcoast.noaa.gov/wms/com.esri.wms.Esrimap/wwa?'
      ,layers     : 'NHC_TRACK_POLY'
      ,singleTile : false
      ,styles     : []
      ,srs        : ['EPSG:4326','EPSG:4267','EPSG:4269','EPSG:102100','EPSG:102113','EPSG:900913']
      ,projection : 'EPSG:900913'
      ,llbbox     : '-180,-90,180,90'
      ,getcaps    : 'http://nowcoast.noaa.gov/wms/com.esri.wms.Esrimap/wwa?service=wms&version=1.1.1&request=GetCapabilities'
    } 
  ];
  for (var i = 0; i < demoLyrs.length; i++) {
    var lyr = new OpenLayers.Layer.WMS(
       demoLyrs[i].name
      ,demoLyrs[i].url
      ,{
         layers      : demoLyrs[i].layers
        ,transparent : true
      }
      ,{
         isBaseLayer   : false
        ,wrapDateLine  : true
        ,singleTile    : demoLyrs[i].singleTile
        ,projection    : demoLyrs[i].projection
      }
    );
    lyr.options.styles = demoLyrs[i].styles;
    lyr.mergeNewParams({STYLES : demoLyrs[i].styles[0]});
    lyr.options.srs = demoLyrs[i].srs;
    lyr.options.llbbox = demoLyrs[i].llbbox;
    lyr.options.getcaps = demoLyrs[i].getcaps;
    map.addLayer(lyr);
    demoGetCapsLinks[demoLyrs[i].getcaps] = false;
  }

  Ext.getCmp('searchField').setValue('hurricane');
  Ext.getCmp('searchField').onTrigger2Click();
}

function checkGetCapsStatus() {
  if (Ext.getCmp('autoSyncButton') && !Ext.getCmp('autoSyncButton').pressed) {
    return;
  }
  if (!initAlertShown) {
    new Ext.Window({
       title : 'Icon descriptions'
      ,items : [{border : false,html : '<table id="initAlert"><tr><td><img src="img/folder.png"></td><td>A GetCaps link that might not be available in the OGC-Search cache.</tr><tr><td><img src="img/folder_explore.png"></td><td>A GetCaps link that is available in the cache.</td></tr></table>'}]
      ,modal : true
      ,constrainHeader : true
    }).show();
    initAlertShown = true;
  }

  function syncGetCapsIcons(u) {
    var imgs = document.getElementsByName(u);
    for (var i = 0; i < imgs.length; i++) {
      if (getCapsLinks[u]) {
        imgs[i].src = 'img/folder_explore.png';
      }
    }
  }

  function syncGetCapsIconsActiveLayers(u) {
    activeLayersStore.each(function(rec) {
      if (rec.get('getCaps') == u) {
        rec.set('getCapsCached',getCapsLinks[u]);
        rec.commit();
      }
    });
  }

  function statusCallback(u,r) {
    var json = new OpenLayers.Format.JSON().read(r.responseText);
    getCapsLinks[u] = json.status == 'OK';
    // log activity
    activityStore.insert(0,new activityStore.recordType({
       i        : activityStore.getCount()
      ,type     : 'status.json'
      ,request  : 'http://ogc-staging.herokuapp.com/wms/status.json'
        + '?url=' + encodeURIComponent(u)
      ,response : json.status
    }));
    syncGetCapsIcons(u);
    syncGetCapsIconsActiveLayers(u);
  }

  for (var u in getCapsLinks) {
    if (!getCapsLinks[u]) {
      OpenLayers.Request.issue({
         method   : 'POST'
        ,url      : 'proxy.php'
        ,headers  : {'Content-Type' : 'application/x-www-form-urlencoded'}
        ,data     : OpenLayers.Util.getParameterString({
          u : 'http://ogc-staging.herokuapp.com/wms/status.json'
            + '?url=' + encodeURIComponent(u)
        })
        ,callback : OpenLayers.Function.bind(statusCallback,null,u)
      });
    }
    else {
      syncGetCapsIcons(u);
      syncGetCapsIconsActiveLayers(u);
    }
  }
}

function parseGetCapsLocally(u) {
  // log activity
  activityStore.insert(0,new activityStore.recordType({
     i        : activityStore.getCount()
    ,type     : 'browser parse'
    ,request  : u
    ,response : 'n/a'
  }));

  new Ext.Window({
     title       : u
    ,id          : 'getCaps'
    ,layout      : 'fit'
    ,width       : 500
    ,height      : 250
    ,autoScroll  : true
    ,bodyStyle   : 'background:white'
    ,constrainHeader : true
    ,items       : [
      new Ext.grid.GridPanel({
         border  : false
        ,id      : 'getCapsGridPanel'
        ,store   : new GeoExt.data.WMSCapabilitiesStore({
           url        : 'proxy.php'
          ,baseParams : {u : u}
          ,autoLoad   : true
          ,sortInfo   : {
             field : 'title'
            ,direction : 'ASC'
          }
        })
        ,columns : [
           {header : 'Title'      ,dataIndex : 'title'   ,sortable : true,id : 'title'}
          ,{header : 'Name'       ,dataIndex : 'name'    ,sortable : true}
          ,{header : 'Description',dataIndex : 'abstract',sortable : true}
        ]
        ,autoExpandColumn : 'title'
        ,loadMask         : true
        ,listeners        : {rowdblclick : function(grid,idx) {
          var lyr = grid.getStore().getAt(idx).getLayer().clone();
          lyr.options.llbbox  = grid.getStore().getAt(idx).get('llbbox');
          lyr.options.getcaps = u;
          lyr.options.styles  = [];
          if (grid.getStore().getAt(idx).get('styles').length > 0) {
            Ext.each(grid.getStore().getAt(idx).get('styles'),function(s) {
              lyr.options.styles.push(s.name);
            });
          }
          lyr.mergeNewParams({STYLES : lyr.options.styles[0]});
          lyr.options.srs = [];
          for (var i in grid.getStore().getAt(idx).get('srs')) {
            lyr.options.srs.push(i);
          }
          map.addLayer(lyr);
        }}
      })
    ]
  }).show();
}

function parseGetCapsFromCache(u) {
  // log activity
  activityStore.insert(0,new activityStore.recordType({
     i        : activityStore.getCount()
    ,type     : 'find.json'
    ,request  : 'http://ogc-staging.herokuapp.com/wms/find.json' + '?url=' + encodeURIComponent(u)
    ,response : 'n/a'
  }));

  new Ext.Window({
     title       : u
    ,id          : 'getCaps'
    ,layout      : 'fit'
    ,width       : 500
    ,height      : 250
    ,autoScroll  : true
    ,bodyStyle   : 'background:white'
    ,constrainHeader : true
    ,items       : [
      new Ext.grid.GridPanel({
         border  : false
        ,id      : 'getCapsGridPanel'
        ,store   : new Ext.data.JsonStore({
           url        : 'proxy.php'
          ,root       : 'wms_layers'
          ,sortInfo   : {
             field     : 'title'
            ,direction : 'ASC'
          }
          ,idProperty : '_id'
          ,fields     : [
             '_id'
            ,'web_mapping_projections'
            ,'name'
            ,'title'
            ,'wms_styles_json'
            ,'abstract'
            ,{mapping : 'server_url',name : 'url'}
            ,'bbox'
          ]
          ,autoLoad   : true
          ,listeners  : {beforeload : function(sto) {
            sto.setBaseParam('u','http://ogc-staging.herokuapp.com/wms/find.json' + '?url=' + encodeURIComponent(u));
          }}
        })
        ,columns : [
           {header : 'Title'      ,dataIndex : 'title'   ,sortable : true,id : 'title'}
          ,{header : 'Name'       ,dataIndex : 'name'    ,sortable : true}
          ,{header : 'Description',dataIndex : 'abstract',sortable : true}
        ]
        ,autoExpandColumn : 'title'
        ,loadMask         : true
        ,listeners        : {rowdblclick : function(grid,idx) {
          var rec = grid.getStore().getAt(idx);
          var lyr = new OpenLayers.Layer.WMS(
             rec.get('title')
            ,rec.get('url').split('?')[0]
            ,{
               layers      : rec.get('name')
              ,transparent : true
            }
            ,{
               isBaseLayer   : false
              ,wrapDateLine  : true
              ,singleTile    : false
            }
          );
          Ext.each(rec.get('wms_styles_json'),function(s) {
            if (!lyr.options.styles) {
              lyr.options.styles = [];
            }
            lyr.options.styles.push(s.name);
          });
          if (!lyr.options.styles) {
            lyr.options.styles = [];
          }
          lyr.mergeNewParams({STYLES : lyr.options.styles[0]});
          lyr.options.srs = rec.get('web_mapping_projections') || [];
          lyr.options.llbbox = new OpenLayers.Format.WKT().read(rec.get('bbox')).geometry.getBounds().toBBOX();
          lyr.options.getcaps = rec.get('url');
          map.addLayer(lyr);
        }}
      })
    ]
  }).show();
}
