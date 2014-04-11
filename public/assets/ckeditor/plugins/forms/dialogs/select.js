/*
Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/
CKEDITOR.dialog.add("select",function(e){function t(e,t,a,n,i){e=d(e);var o;return o=n?n.createElement("OPTION"):document.createElement("OPTION"),e&&o&&"option"==o.getName()?(CKEDITOR.env.ie?(isNaN(parseInt(i,10))?e.$.options.add(o.$):e.$.options.add(o.$,i),o.$.innerHTML=t.length>0?t:"",o.$.value=a):(null!==i&&i<e.getChildCount()?e.getChild(0>i?0:i).insertBeforeMe(o):e.append(o),o.setText(t.length>0?t:""),o.setValue(a)),o):!1}function a(e){e=d(e);for(var t=r(e),a=e.getChildren().count()-1;a>=0;a--)e.getChild(a).$.selected&&e.getChild(a).remove();s(e,t)}function n(e,t,a,n){if(e=d(e),0>t)return!1;var i=e.getChild(t);return i.setText(a),i.setValue(n),i}function i(e){for(e=d(e);e.getChild(0)&&e.getChild(0).remove(););}function o(e,a,n){e=d(e);var i=r(e);if(0>i)return!1;var o=i+a;if(o=0>o?0:o,o=o>=e.getChildCount()?e.getChildCount()-1:o,i==o)return!1;var l=e.getChild(i),c=l.getText(),u=l.getValue();return l.remove(),l=t(e,c,u,n?n:null,o),s(e,o),l}function r(e){return e=d(e),e?e.$.selectedIndex:-1}function s(e,t){if(e=d(e),0>t)return null;var a=e.getChildren().count();return e.$.selectedIndex=t>=a?a-1:t,e}function l(e){return e=d(e),e?e.getChildren():!1}function d(e){return e&&e.domId&&e.getInputElement().$?e.getInputElement():e&&e.$?e:!1}return{title:e.lang.select.title,minWidth:CKEDITOR.env.ie?460:395,minHeight:CKEDITOR.env.ie?320:300,onShow:function(){var e=this;delete e.selectBox,e.setupContent("clear");var t=e.getParentEditor().getSelection().getSelectedElement();if(t&&"select"==t.getName()){e.selectBox=t,e.setupContent(t.getName(),t);for(var a=l(t),n=0;n<a.count();n++)e.setupContent("option",a.getItem(n))}},onOk:function(){var e=this.getParentEditor(),t=this.selectBox,a=!t;if(a&&(t=e.document.createElement("select")),this.commitContent(t),a&&(e.insertElement(t),CKEDITOR.env.ie)){var n=e.getSelection(),i=n.createBookmarks();setTimeout(function(){n.selectBookmarks(i)},0)}},contents:[{id:"info",label:e.lang.select.selectInfo,title:e.lang.select.selectInfo,accessKey:"",elements:[{id:"txtName",type:"text",widths:["25%","75%"],labelLayout:"horizontal",label:e.lang.common.name,"default":"",accessKey:"N",style:"width:350px",setup:function(e,t){"clear"==e?this.setValue(this["default"]||""):"select"==e&&this.setValue(t.data("cke-saved-name")||t.getAttribute("name")||"")},commit:function(e){this.getValue()?e.data("cke-saved-name",this.getValue()):(e.data("cke-saved-name",!1),e.removeAttribute("name"))}},{id:"txtValue",type:"text",widths:["25%","75%"],labelLayout:"horizontal",label:e.lang.select.value,style:"width:350px","default":"",className:"cke_disabled",onLoad:function(){this.getInputElement().setAttribute("readOnly",!0)},setup:function(e,t){"clear"==e?this.setValue(""):"option"==e&&t.getAttribute("selected")&&this.setValue(t.$.value)}},{type:"hbox",widths:["175px","170px"],children:[{id:"txtSize",type:"text",labelLayout:"horizontal",label:e.lang.select.size,"default":"",accessKey:"S",style:"width:175px",validate:function(){var t=CKEDITOR.dialog.validate.integer(e.lang.common.validateNumberFailed);return""===this.getValue()||t.apply(this)},setup:function(e,t){"select"==e&&this.setValue(t.getAttribute("size")||""),CKEDITOR.env.webkit&&this.getInputElement().setStyle("width","86px")},commit:function(e){this.getValue()?e.setAttribute("size",this.getValue()):e.removeAttribute("size")}},{type:"html",html:"<span>"+CKEDITOR.tools.htmlEncode(e.lang.select.lines)+"</span>"}]},{type:"html",html:"<span>"+CKEDITOR.tools.htmlEncode(e.lang.select.opAvail)+"</span>"},{type:"hbox",widths:["115px","115px","100px"],children:[{type:"vbox",children:[{id:"txtOptName",type:"text",label:e.lang.select.opText,style:"width:115px",setup:function(e){"clear"==e&&this.setValue("")}},{type:"select",id:"cmbName",label:"",title:"",size:5,style:"width:115px;height:75px",items:[],onChange:function(){var e=this.getDialog(),t=e.getContentElement("info","cmbValue"),a=e.getContentElement("info","txtOptName"),n=e.getContentElement("info","txtOptValue"),i=r(this);s(t,i),a.setValue(this.getValue()),n.setValue(t.getValue())},setup:function(e,a){"clear"==e?i(this):"option"==e&&t(this,a.getText(),a.getText(),this.getDialog().getParentEditor().document)},commit:function(e){var a=this.getDialog(),n=l(this),o=l(a.getContentElement("info","cmbValue")),r=a.getContentElement("info","txtValue").getValue();i(e);for(var s=0;s<n.count();s++){var d=t(e,n.getItem(s).getValue(),o.getItem(s).getValue(),a.getParentEditor().document);o.getItem(s).getValue()==r&&(d.setAttribute("selected","selected"),d.selected=!0)}}}]},{type:"vbox",children:[{id:"txtOptValue",type:"text",label:e.lang.select.opValue,style:"width:115px",setup:function(e){"clear"==e&&this.setValue("")}},{type:"select",id:"cmbValue",label:"",size:5,style:"width:115px;height:75px",items:[],onChange:function(){var e=this.getDialog(),t=e.getContentElement("info","cmbName"),a=e.getContentElement("info","txtOptName"),n=e.getContentElement("info","txtOptValue"),i=r(this);s(t,i),a.setValue(t.getValue()),n.setValue(this.getValue())},setup:function(e,a){var n=this;if("clear"==e)i(n);else if("option"==e){var o=a.getValue();t(n,o,o,n.getDialog().getParentEditor().document),"selected"==a.getAttribute("selected")&&n.getDialog().getContentElement("info","txtValue").setValue(o)}}}]},{type:"vbox",padding:5,children:[{type:"button",id:"btnAdd",style:"",label:e.lang.select.btnAdd,title:e.lang.select.btnAdd,style:"width:100%;",onClick:function(){var e=this.getDialog(),a=(e.getParentEditor(),e.getContentElement("info","txtOptName")),n=e.getContentElement("info","txtOptValue"),i=e.getContentElement("info","cmbName"),o=e.getContentElement("info","cmbValue");t(i,a.getValue(),a.getValue(),e.getParentEditor().document),t(o,n.getValue(),n.getValue(),e.getParentEditor().document),a.setValue(""),n.setValue("")}},{type:"button",id:"btnModify",label:e.lang.select.btnModify,title:e.lang.select.btnModify,style:"width:100%;",onClick:function(){var e=this.getDialog(),t=e.getContentElement("info","txtOptName"),a=e.getContentElement("info","txtOptValue"),i=e.getContentElement("info","cmbName"),o=e.getContentElement("info","cmbValue"),s=r(i);s>=0&&(n(i,s,t.getValue(),t.getValue()),n(o,s,a.getValue(),a.getValue()))}},{type:"button",id:"btnUp",style:"width:100%;",label:e.lang.select.btnUp,title:e.lang.select.btnUp,onClick:function(){var e=this.getDialog(),t=e.getContentElement("info","cmbName"),a=e.getContentElement("info","cmbValue");o(t,-1,e.getParentEditor().document),o(a,-1,e.getParentEditor().document)}},{type:"button",id:"btnDown",style:"width:100%;",label:e.lang.select.btnDown,title:e.lang.select.btnDown,onClick:function(){var e=this.getDialog(),t=e.getContentElement("info","cmbName"),a=e.getContentElement("info","cmbValue");o(t,1,e.getParentEditor().document),o(a,1,e.getParentEditor().document)}}]}]},{type:"hbox",widths:["40%","20%","40%"],children:[{type:"button",id:"btnSetValue",label:e.lang.select.btnSetValue,title:e.lang.select.btnSetValue,onClick:function(){var e=this.getDialog(),t=e.getContentElement("info","cmbValue"),a=e.getContentElement("info","txtValue");a.setValue(t.getValue())}},{type:"button",id:"btnDelete",label:e.lang.select.btnDelete,title:e.lang.select.btnDelete,onClick:function(){var e=this.getDialog(),t=e.getContentElement("info","cmbName"),n=e.getContentElement("info","cmbValue"),i=e.getContentElement("info","txtOptName"),o=e.getContentElement("info","txtOptValue");a(t),a(n),i.setValue(""),o.setValue("")}},{id:"chkMulti",type:"checkbox",label:e.lang.select.chkMulti,"default":"",accessKey:"M",value:"checked",setup:function(e,t){"select"==e&&this.setValue(t.getAttribute("multiple")),CKEDITOR.env.webkit&&this.getElement().getParent().setStyle("vertical-align","middle")},commit:function(e){this.getValue()?e.setAttribute("multiple",this.getValue()):e.removeAttribute("multiple")}}]}]}]}});