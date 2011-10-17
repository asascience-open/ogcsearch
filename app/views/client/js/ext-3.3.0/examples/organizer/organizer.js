/*!
 * Ext JS Library 3.3.0
 * Copyright(c) 2006-2010 Ext JS, Inc.
 * licensing@extjs.com
 * http://www.extjs.com/license
 */
Ext.onReady(function(){

    Ext.QuickTips.init();

    var view = new Ext.DataView({
        itemSelector: 'div.thumb-wrap',
        style:'overflow:auto',
        store:  new Ext.data.JsonStore({
     url           : '/secoora/data.php'
    ,root          : 'inventory'
    ,totalProperty : 'totalCount'
    ,idProperty    : 'id'
    ,remoteSort    : true
    ,fields        : [
       'id'
      ,'title'
      ,'institute'
      ,'variable'
      ,'abstract'
      ,'extent_geographic'
      ,'extent_temporal'
      ,'url_thumbnail'
      ,'url_details'
      ,'url_legend'
      ,'wms_base'
      ,'wms_layers'
    ]
    ,baseParams    : {
      limit : 25
    }
    ,autoLoad : true
  }),
        tpl: new Ext.XTemplate(
            '<tpl for=".">',
            '<div class="thumb-wrap" id="{name}">',
            '<div class="thumb"><img src="{url_thumb}" class="thumb-img"></div>',
            '<span>{shortName}</span></div>',
            '</tpl>'
        )
    });

    var images = new Ext.Panel({
        id:'images',
        title:'My Images',
        region:'center',
        margins: '5 5 5 0',
        // layout:'border',
        
        items: view
    });

    var layout = new Ext.Window({
        applyTo: 'layout',
        width:300,
        height:400,
        items: [images]
        ,layout : 'fit'
        ,resizable : true
    }).show();


});
