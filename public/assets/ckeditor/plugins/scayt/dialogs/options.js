/*
Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/
CKEDITOR.dialog.add("scaytcheck",function(e){function t(){return"undefined"!=typeof document.forms["optionsbar_"+m]?document.forms["optionsbar_"+m].options:[]}function a(){return"undefined"!=typeof document.forms["languagesbar_"+m]?document.forms["languagesbar_"+m].scayt_lang:[]}function n(e,t){if(e){var a=e.length;if(void 0==a)return e.checked=e.value==t.toString(),void 0;for(var n=0;a>n;n++)e[n].checked=!1,e[n].value==t.toString()&&(e[n].checked=!0)}}function i(e){p.getById("dic_message_"+m).setHtml('<span style="color:red;">'+e+"</span>")}function o(e){p.getById("dic_message_"+m).setHtml('<span style="color:blue;">'+e+"</span>")}function r(e){e=String(e);for(var t=e.split(","),a=0,n=t.length;n>a;a+=1)p.getById(t[a]).$.style.display="inline"}function l(e){e=String(e);for(var t=e.split(","),a=0,n=t.length;n>a;a+=1)p.getById(t[a]).$.style.display="none"}function s(e){p.getById("dic_name_"+m).$.value=e}var d,c,u=!0,p=CKEDITOR.document,m=e.name,h=CKEDITOR.plugins.scayt.getUiTabs(e),g=[],f=0,v=["dic_create_"+m+",dic_restore_"+m,"dic_rename_"+m+",dic_delete_"+m],b=["mixedCase","mixedWithDigits","allCaps","ignoreDomainNames"],y=e.lang.scayt,k=[{id:"options",label:y.optionsTab,elements:[{type:"html",id:"options",html:'<form name="optionsbar_'+m+'"><div class="inner_options">'+'	<div class="messagebox"></div>'+'	<div style="display:none;">'+'		<input type="checkbox" name="options"  id="allCaps_'+m+'" />'+'		<label for="allCaps" id="label_allCaps_'+m+'"></label>'+"	</div>"+'	<div style="display:none;">'+'		<input name="options" type="checkbox"  id="ignoreDomainNames_'+m+'" />'+'		<label for="ignoreDomainNames" id="label_ignoreDomainNames_'+m+'"></label>'+"	</div>"+'	<div style="display:none;">'+'	<input name="options" type="checkbox"  id="mixedCase_'+m+'" />'+'		<label for="mixedCase" id="label_mixedCase_'+m+'"></label>'+"	</div>"+'	<div style="display:none;">'+'		<input name="options" type="checkbox"  id="mixedWithDigits_'+m+'" />'+'		<label for="mixedWithDigits" id="label_mixedWithDigits_'+m+'"></label>'+"	</div>"+"</div></form>"}]},{id:"langs",label:y.languagesTab,elements:[{type:"html",id:"langs",html:'<form name="languagesbar_'+m+'"><div class="inner_langs">'+'	<div class="messagebox"></div>	'+'   <div style="float:left;width:45%;margin-left:5px;" id="scayt_lcol_'+m+'" ></div>'+'   <div style="float:left;width:45%;margin-left:15px;" id="scayt_rcol_'+m+'"></div>'+"</div></form>"}]},{id:"dictionaries",label:y.dictionariesTab,elements:[{type:"html",style:"",id:"dictionaries",html:'<form name="dictionarybar_'+m+'"><div class="inner_dictionary" style="text-align:left; white-space:normal; width:320px; overflow: hidden;">'+'	<div style="margin:5px auto; width:80%;white-space:normal; overflow:hidden;" id="dic_message_'+m+'"> </div>'+'	<div style="margin:5px auto; width:80%;white-space:normal;"> '+'       <span class="cke_dialog_ui_labeled_label" >Dictionary name</span><br>'+'		<span class="cke_dialog_ui_labeled_content" >'+'			<div class="cke_dialog_ui_input_text">'+'				<input id="dic_name_'+m+'" type="text" class="cke_dialog_ui_input_text"/>'+"		</div></span></div>"+'		<div style="margin:5px auto; width:80%;white-space:normal;">'+'			<a style="display:none;" class="cke_dialog_ui_button" href="javascript:void(0)" id="dic_create_'+m+'">'+"				</a>"+'			<a  style="display:none;" class="cke_dialog_ui_button" href="javascript:void(0)" id="dic_delete_'+m+'">'+"				</a>"+'			<a  style="display:none;" class="cke_dialog_ui_button" href="javascript:void(0)" id="dic_rename_'+m+'">'+"				</a>"+'			<a  style="display:none;" class="cke_dialog_ui_button" href="javascript:void(0)" id="dic_restore_'+m+'">'+"				</a>"+"		</div>"+'	<div style="margin:5px auto; width:95%;white-space:normal;" id="dic_info_'+m+'"></div>'+"</div></form>"}]},{id:"about",label:y.aboutTab,elements:[{type:"html",id:"about",style:"margin: 5px 5px;",html:'<div id="scayt_about_'+m+'"></div>'}]}],C={title:y.title,minWidth:360,minHeight:220,onShow:function(){var t=this;if(t.data=e.fire("scaytDialog",{}),t.options=t.data.scayt_control.option(),t.chosed_lang=t.sLang=t.data.scayt_control.sLang,!t.data||!t.data.scayt||!t.data.scayt_control)return alert("Error loading application service"),t.hide(),void 0;var a=0;u?t.data.scayt.getCaption(e.langCode||"en",function(e){a++>0||(d=e,w.apply(t),_.apply(t),u=!1)}):_.apply(t),t.selectPage(t.data.tab)},onOk:function(){var e=this.data.scayt_control;e.option(this.options);var t=this.chosed_lang;e.setLang(t),e.refresh()},onCancel:function(){var e=t();for(var i in e)e[i].checked=!1;n(a(),"")},contents:g};for(CKEDITOR.plugins.scayt.getScayt(e),c=0;c<h.length;c++)1==h[c]&&(g[g.length]=k[c]);1==h[2]&&(f=1);var w=function(){function e(e){var t=p.getById("dic_name_"+m).getValue();if(!t)return i(" Dictionary name should not be empty. "),!1;try{var a=e.data.getTarget().getParent(),n=/(dic_\w+)_[\w\d]+/.exec(a.getId())[1];D[n].apply(null,[a,t,v])}catch(o){i(" Dictionary error. ")}return!0}var t,a=this,n=a.data.scayt.getLangList(),c=["dic_create","dic_delete","dic_rename","dic_restore"],u=[],g=[],y=b;if(f){for(t=0;t<c.length;t++)u[t]=c[t]+"_"+m,p.getById(u[t]).setHtml('<span class="cke_dialog_ui_button">'+d["button_"+c[t]]+"</span>");p.getById("dic_info_"+m).setHtml(d.dic_info)}if(1==h[0])for(t in y){var k="label_"+y[t],C=k+"_"+m,w=p.getById(C);if("undefined"!=typeof w&&"undefined"!=typeof d[k]&&"undefined"!=typeof a.options[y[t]]){w.setHtml(d[k]);var _=w.getParent();_.$.style.display="block"}}var T='<p><img src="'+window.scayt.getAboutInfo().logoURL+'" /></p>'+"<p>"+d.version+window.scayt.getAboutInfo().version.toString()+"</p>"+"<p>"+d.about_throwt_copy+"</p>";p.getById("scayt_about_"+m).setHtml(T);var S=function(e,t){var n=p.createElement("label");n.setAttribute("for","cke_option"+e),n.setHtml(t[e]),a.sLang==e&&(a.chosed_lang=e);var i=p.createElement("div"),o=CKEDITOR.dom.element.createFromHtml('<input id="cke_option'+e+'" type="radio" '+(a.sLang==e?'checked="checked"':"")+' value="'+e+'" name="scayt_lang" />');return o.on("click",function(){this.$.checked=!0,a.chosed_lang=e}),i.append(o),i.append(n),{lang:t[e],code:e,radio:i}};if(1==h[1]){for(t in n.rtl)g[g.length]=S(t,n.ltr);for(t in n.ltr)g[g.length]=S(t,n.ltr);g.sort(function(e,t){return t.lang>e.lang?-1:1});var x=p.getById("scayt_lcol_"+m),A=p.getById("scayt_rcol_"+m);for(t=0;t<g.length;t++){var E=t<g.length/2?x:A;E.append(g[t].radio)}}var D={};D.dic_create=function(e,t,a){var n=a[0]+","+a[1],s=d.err_dic_create,c=d.succ_dic_create;window.scayt.createUserDictionary(t,function(e){l(n),r(a[1]),c=c.replace("%s",e.dname),o(c)},function(e){s=s.replace("%s",e.dname),i(s+"( "+(e.message||"")+")")})},D.dic_rename=function(e,t){var a=d.err_dic_rename||"",n=d.succ_dic_rename||"";window.scayt.renameUserDictionary(t,function(e){n=n.replace("%s",e.dname),s(t),o(n)},function(e){a=a.replace("%s",e.dname),s(t),i(a+"( "+(e.message||"")+" )")})},D.dic_delete=function(e,t,a){var n=a[0]+","+a[1],c=d.err_dic_delete,u=d.succ_dic_delete;window.scayt.deleteUserDictionary(function(e){u=u.replace("%s",e.dname),l(n),r(a[0]),s(""),o(u)},function(e){c=c.replace("%s",e.dname),i(c)})},D.dic_restore=a.dic_restore||function(e,t,a){var n=a[0]+","+a[1],s=d.err_dic_restore,c=d.succ_dic_restore;window.scayt.restoreUserDictionary(t,function(e){c=c.replace("%s",e.dname),l(n),r(a[1]),o(c)},function(e){s=s.replace("%s",e.dname),i(s)})};var I,F=(v[0]+","+v[1]).split(",");for(t=0,I=F.length;I>t;t+=1){var L=p.getById(F[t]);L&&L.on("click",e,this)}},_=function(){var e=this;if(1==h[0])for(var a=t(),i=0,s=a.length;s>i;i++){var d=a[i].id,c=p.getById(d);c&&(a[i].checked=!1,1==e.options[d.split("_")[0]]&&(a[i].checked=!0),u&&c.on("click",function(){e.options[this.getId().split("_")[0]]=this.$.checked?1:0}))}if(1==h[1]){var g=p.getById("cke_option"+e.sLang);n(g.$,e.sLang)}f&&(window.scayt.getNameUserDictionary(function(e){var t=e.dname;l(v[0]+","+v[1]),t?(p.getById("dic_name_"+m).setValue(t),r(v[1])):r(v[0])},function(){p.getById("dic_name_"+m).setValue("")}),o(""))};return C});