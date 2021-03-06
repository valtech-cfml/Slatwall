/*

    Slatwall - An e-commerce plugin for Mura CMS
    Copyright (C) 2011 ten24, LLC

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Linking this library statically or dynamically with other modules is
    making a combined work based on this library.  Thus, the terms and
    conditions of the GNU General Public License cover the whole
    combination.
 
    As a special exception, the copyright holders of this library give you
    permission to link this library with independent modules to produce an
    executable, regardless of the license terms of these independent
    modules, and to copy and distribute the resulting executable under
    terms of your choice, provided that you also meet, for each linked
    independent module, the terms and conditions of the license of that
    module.  An independent module is a module which is not derived from
    or based on this library.  If you modify this library, you may extend
    this exception to your version of the library, but you are not
    obligated to do so.  If you do not wish to do so, delete this
    exception statement from your version.

Notes:

*/
component extends="BaseController" persistent="false" accessors="true" output="false" {

	// fw1 Auto-Injected Service Properties
	property name="attributeService" type="any";

	public void function default(required struct rc) {
		getFW().redirect(action="admin:attribute.listAttributeSets");
	}
	
	public void function listAttributeSets(required struct rc) {
        rc.attributeSetSmartList = getAttributeService().getAttributeSetSmartList();
    }
    
	public void function createAttributeSet(required struct rc) {
		rc.edit = true;
		getFW().setView("admin:attribute.detailattributeset");
		
		rc.attributeSet = getAttributeService().newAttributeSet();
		rc.attribute = getAttributeService().newAttribute();
	}
	
	public void function editAttributeSet(required struct rc) {
		param name="rc.attributeSetID" default="";
		param name="rc.attributeID" default="";
		
		rc.edit = true;
		getFW().setView("admin:attribute.detailattributeset");
		
		rc.attributeSet = getAttributeService().getAttributeSet(rc.attributeSetID);
		rc.attribute = getAttributeService().getAttribute(rc.attributeID, true);
		
		if(isNull(rc.attributeSet)) {
			getFW().redirect(action="admin:attribute.listAttributeSets");
		}
	}
	
	public void function saveAttributeSet(required struct rc) {
		param name="rc.attributeSetID" default="";
		param name="rc.populateSubProperties" default="false";
		
		rc.attributeSet = getAttributeService().getAttributeSet(rc.attributeSetID, true);
		rc.attribute = getAttributeService().newAttribute();
		
		rc.attributeSet = getAttributeService().saveAttributeSet(rc.attributeSet, rc);
		
		if(!rc.attributeSet.hasErrors()) {
			rc.message=rc.$.Slatwall.rbKey("admin.attribute.saveAttributeSet_success");
			if(rc.populateSubProperties) {
				getFW().redirect(action="admin:attribute.editAttributeSet",querystring="attributeSetID=#rc.attributeSet.getAttributeSetID()#",preserve="message");	
			} else {
				getFW().redirect(action="admin:attribute.listAttributeSets",preserve="message");
			}
		} else {
			// If one of the attributes had the error, then find out which one and populate it
			if(rc.attributeSet.hasError("attributes")) {
				for(var i=1; i<=arrayLen(rc.attributeSet.getAttributes()); i++) {
					if(rc.attributeSet.getAttributes()[i].hasErrors()) {
						rc.attribute = rc.attributeSet.getAttributes()[i];
					}
				}
			}
			rc.edit = true;
			rc.itemTitle = rc.AttributeSet.isNew() ? rc.$.Slatwall.rbKey("admin.attribute.createAttributeSet") : rc.$.Slatwall.rbKey("admin.attribute.editAttributeSet") & ": #rc.attributeSet.getAttributeSetName()#";
			getFW().setView(action="admin:attribute.detailAttributeSet");
		}
	}
	
	public void function deleteAttributeSet(required struct rc) {
		param name="rc.attributeSetID" default="";
		
		var attributeSet = getAttributeService().getAttributeSet(rc.attributeSetID);
		
		var deleteOK = getAttributeService().deleteAttributeSet(attributeSet);
		
		if( deleteOK ) {
			rc.message = rbKey("admin.attributeSet.deleteAttributeSet_success");
		} else {
			rc.message = rbKey("admin.attributeSet.deleteAttributeSet_failure");
			rc.messagetype="error";
		}
		
		getFW().redirect(action="admin:attribute.listAttributeSets", preserve="message,messagetype");
	}
	
	public void function deleteAttribute(required struct rc) {
		param name="rc.attributeID" default="";
		param name="rc.attributeSetID" default="";
		
		var attribute = getAttributeService().getAttribute(rc.attributeID);
		
		var deleteOK = getAttributeService().deleteAttribute(attribute);
		
		if( deleteOK ) {
			rc.message = rbKey("admin.attribute.deleteAttribute_success");
		} else {
			rc.message = rbKey("admin.attribute.deleteAttribute_failure");
			rc.messagetype="error";
		}
		
		getFW().redirect(action="admin:attribute.editAttributeSet", queryString="attributeSetID=#rc.attributeSetID#", preserve="message,messagetype");
	}
	
	public void function deleteAttributeOption(required struct rc) {
		param name="rc.attributeOptionID" default="";
		param name="rc.attributeSetID" default="";
		param name="rc.attributeID" default="";
		
		var attributeOption = getAttributeService().getAttributeOption(rc.attributeOptionID);
		
		var deleteOK = getAttributeService().deleteAttributeOption(attributeOption);
		
		if( deleteOK ) {
			rc.message = rbKey("admin.attribute.deleteAttributeOption_success");
		} else {
			rc.message = rbKey("admin.attribute.deleteAttributeOption_failure");
			rc.messagetype="error";
		}
		
		getFW().redirect(action="admin:attribute.editAttributeSet", queryString="attributeSetID=#rc.attributeSetID#&attributeID=#rc.attributeID#", preserve="message,messagetype");
	}
	
}
