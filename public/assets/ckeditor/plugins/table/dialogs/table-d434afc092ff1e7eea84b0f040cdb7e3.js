/*
Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/
!function(){function e(e){for(var t,a=0,i=0,n=0,o=e.$.rows.length;o>n;n++){t=e.$.rows[n],a=0;for(var r,l=0,s=t.cells.length;s>l;l++)r=t.cells[l],a+=r.colSpan;a>i&&(i=a)}return i}function t(e){return function(){var t=this.getValue(),a=!!(CKEDITOR.dialog.validate.integer()(t)&&t>0);return a||(alert(e),this.select()),a}}function a(a,o){var r=function(e){return new CKEDITOR.dom.element(e,a.document)},l=a.plugins.dialogadvtab;return{title:a.lang.table.title,minWidth:310,minHeight:CKEDITOR.env.ie?310:280,onLoad:function(){var e=this,t=e.getContentElement("advanced","advStyles");t&&t.on("change",function(){var t=this.getStyle("width",""),a=e.getContentElement("info","txtWidth");a&&a.setValue(t,!0);var i=this.getStyle("height",""),n=e.getContentElement("info","txtHeight");n&&n.setValue(i,!0)})},onShow:function(){var e=this,t=a.getSelection(),i=t.getRanges(),n=null,r=e.getContentElement("info","txtRows"),l=e.getContentElement("info","txtCols"),s=e.getContentElement("info","txtWidth"),d=e.getContentElement("info","txtHeight");if("tableProperties"==o){if(n=t.getSelectedElement())n=n.getAscendant("table",!0);else if(i.length>0){CKEDITOR.env.webkit&&i[0].shrink(CKEDITOR.NODE_ELEMENT);var c=i[0].getCommonAncestor(!0);n=c.getAscendant("table",!0)}e._.selectedElement=n}n?(e.setupContent(n),r&&r.disable(),l&&l.disable()):(r&&r.enable(),l&&l.enable()),s&&s.onChange(),d&&d.onChange()},onOk:function(){var e=a.getSelection(),t=this._.selectedElement&&e.createBookmarks(),i=this._.selectedElement||r("table"),n={};if(this.commitContent(n,i),n.info){var o=n.info;if(!this._.selectedElement)for(var l=i.append(r("tbody")),s=parseInt(o.txtRows,10)||0,d=parseInt(o.txtCols,10)||0,c=0;s>c;c++)for(var u=l.append(r("tr")),m=0;d>m;m++){var p=u.append(r("td"));CKEDITOR.env.ie||p.append(r("br"))}var h=o.selHeaders;if(!i.$.tHead&&("row"==h||"both"==h)){var g=new CKEDITOR.dom.element(i.$.createTHead());l=i.getElementsByTag("tbody").getItem(0);var f=l.getElementsByTag("tr").getItem(0);for(c=0;c<f.getChildCount();c++){var v=f.getChild(c);v.type!=CKEDITOR.NODE_ELEMENT||v.data("cke-bookmark")||(v.renameNode("th"),v.setAttribute("scope","col"))}g.append(f.remove())}if(null!==i.$.tHead&&"row"!=h&&"both"!=h){g=new CKEDITOR.dom.element(i.$.tHead),l=i.getElementsByTag("tbody").getItem(0);for(var b=l.getFirst();g.getChildCount()>0;){for(f=g.getFirst(),c=0;c<f.getChildCount();c++){var y=f.getChild(c);y.type==CKEDITOR.NODE_ELEMENT&&(y.renameNode("td"),y.removeAttribute("scope"))}f.insertBefore(b)}g.remove()}if(!this.hasColumnHeaders&&("col"==h||"both"==h))for(u=0;u<i.$.rows.length;u++)y=new CKEDITOR.dom.element(i.$.rows[u].cells[0]),y.renameNode("th"),y.setAttribute("scope","row");if(this.hasColumnHeaders&&"col"!=h&&"both"!=h)for(c=0;c<i.$.rows.length;c++)u=new CKEDITOR.dom.element(i.$.rows[c]),"tbody"==u.getParent().getName()&&(y=new CKEDITOR.dom.element(u.$.cells[0]),y.renameNode("td"),y.removeAttribute("scope"));o.txtHeight?i.setStyle("height",o.txtHeight):i.removeStyle("height"),o.txtWidth?i.setStyle("width",o.txtWidth):i.removeStyle("width"),i.getAttribute("style")||i.removeAttribute("style")}if(this._.selectedElement)try{e.selectBookmarks(t)}catch(k){}else a.insertElement(i),setTimeout(function(){var e=new CKEDITOR.dom.element(i.$.rows[0].cells[0]),t=new CKEDITOR.dom.range(a.document);t.moveToPosition(e,CKEDITOR.POSITION_AFTER_START),t.select(1)},0)},contents:[{id:"info",label:a.lang.table.title,elements:[{type:"hbox",widths:[null,null],styles:["vertical-align:top"],children:[{type:"vbox",padding:0,children:[{type:"text",id:"txtRows","default":3,label:a.lang.table.rows,required:!0,controlStyle:"width:5em",validate:t(a.lang.table.invalidRows),setup:function(e){this.setValue(e.$.rows.length)},commit:n},{type:"text",id:"txtCols","default":2,label:a.lang.table.columns,required:!0,controlStyle:"width:5em",validate:t(a.lang.table.invalidCols),setup:function(t){this.setValue(e(t))},commit:n},{type:"html",html:"&nbsp;"},{type:"select",id:"selHeaders","default":"",label:a.lang.table.headers,items:[[a.lang.table.headersNone,""],[a.lang.table.headersRow,"row"],[a.lang.table.headersColumn,"col"],[a.lang.table.headersBoth,"both"]],setup:function(e){var t=this.getDialog();t.hasColumnHeaders=!0;for(var a=0;a<e.$.rows.length;a++){var i=e.$.rows[a].cells[0];if(i&&"th"!=i.nodeName.toLowerCase()){t.hasColumnHeaders=!1;break}}null!==e.$.tHead?this.setValue(t.hasColumnHeaders?"both":"row"):this.setValue(t.hasColumnHeaders?"col":"")},commit:n},{type:"text",id:"txtBorder","default":1,label:a.lang.table.border,controlStyle:"width:3em",validate:CKEDITOR.dialog.validate.number(a.lang.table.invalidBorder),setup:function(e){this.setValue(e.getAttribute("border")||"")},commit:function(e,t){this.getValue()?t.setAttribute("border",this.getValue()):t.removeAttribute("border")}},{id:"cmbAlign",type:"select","default":"",label:a.lang.common.align,items:[[a.lang.common.notSet,""],[a.lang.common.alignLeft,"left"],[a.lang.common.alignCenter,"center"],[a.lang.common.alignRight,"right"]],setup:function(e){this.setValue(e.getAttribute("align")||"")},commit:function(e,t){this.getValue()?t.setAttribute("align",this.getValue()):t.removeAttribute("align")}}]},{type:"vbox",padding:0,children:[{type:"hbox",widths:["5em"],children:[{type:"text",id:"txtWidth",controlStyle:"width:5em",label:a.lang.common.width,title:a.lang.common.cssLengthTooltip,"default":500,getValue:i,validate:CKEDITOR.dialog.validate.cssLength(a.lang.common.invalidCssLength.replace("%1",a.lang.common.width)),onChange:function(){var e=this.getDialog().getContentElement("advanced","advStyles");e&&e.updateStyle("width",this.getValue())},setup:function(e){var t=e.getStyle("width");t&&this.setValue(t)},commit:n}]},{type:"hbox",widths:["5em"],children:[{type:"text",id:"txtHeight",controlStyle:"width:5em",label:a.lang.common.height,title:a.lang.common.cssLengthTooltip,"default":"",getValue:i,validate:CKEDITOR.dialog.validate.cssLength(a.lang.common.invalidCssLength.replace("%1",a.lang.common.height)),onChange:function(){var e=this.getDialog().getContentElement("advanced","advStyles");e&&e.updateStyle("height",this.getValue())},setup:function(e){var t=e.getStyle("height");t&&this.setValue(t)},commit:n}]},{type:"html",html:"&nbsp;"},{type:"text",id:"txtCellSpace",controlStyle:"width:3em",label:a.lang.table.cellSpace,"default":1,validate:CKEDITOR.dialog.validate.number(a.lang.table.invalidCellSpacing),setup:function(e){this.setValue(e.getAttribute("cellSpacing")||"")},commit:function(e,t){this.getValue()?t.setAttribute("cellSpacing",this.getValue()):t.removeAttribute("cellSpacing")}},{type:"text",id:"txtCellPad",controlStyle:"width:3em",label:a.lang.table.cellPad,"default":1,validate:CKEDITOR.dialog.validate.number(a.lang.table.invalidCellPadding),setup:function(e){this.setValue(e.getAttribute("cellPadding")||"")},commit:function(e,t){this.getValue()?t.setAttribute("cellPadding",this.getValue()):t.removeAttribute("cellPadding")}}]}]},{type:"html",align:"right",html:""},{type:"vbox",padding:0,children:[{type:"text",id:"txtCaption",label:a.lang.table.caption,setup:function(e){var t=this;t.enable();var a=e.getElementsByTag("caption");if(a.count()>0){var i=a.getItem(0),n=i.getFirst(CKEDITOR.dom.walker.nodeType(CKEDITOR.NODE_ELEMENT));if(n&&!n.equals(i.getBogus()))return t.disable(),t.setValue(i.getText()),void 0;i=CKEDITOR.tools.trim(i.getText()),t.setValue(i)}},commit:function(e,t){if(this.isEnabled()){var i=this.getValue(),n=t.getElementsByTag("caption");if(i)n.count()>0?(n=n.getItem(0),n.setHtml("")):(n=new CKEDITOR.dom.element("caption",a.document),t.getChildCount()?n.insertBefore(t.getFirst()):n.appendTo(t)),n.append(new CKEDITOR.dom.text(i,a.document));else if(n.count()>0)for(var o=n.count()-1;o>=0;o--)n.getItem(o).remove()}}},{type:"text",id:"txtSummary",label:a.lang.table.summary,setup:function(e){this.setValue(e.getAttribute("summary")||"")},commit:function(e,t){this.getValue()?t.setAttribute("summary",this.getValue()):t.removeAttribute("summary")}}]}]},l&&l.createAdvancedTab(a)]}}var i=CKEDITOR.tools.cssLength,n=function(e){var t=this.id;e.info||(e.info={}),e.info[t]=this.getValue()};CKEDITOR.dialog.add("table",function(e){return a(e,"table")}),CKEDITOR.dialog.add("tableProperties",function(e){return a(e,"tableProperties")})}();