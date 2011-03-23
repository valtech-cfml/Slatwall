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
component extends="framework" output="false" {

	include "../../config/applicationSettings.cfm";
	include "../../config/mappings.cfm";
	include "../mappings.cfm";
	include "fw1Config.cfm";
	
	variables.subsystems = {};
	variables.subsystems.admin = {};
	variables.subsystems.admin.baseURL = "";
	variables.subsystems.frontend = {};
	variables.subsystems.frontend.baseURL = "";

	public void function setPluginConfig(required any pluginConfig) {
		application[ variables.framework.applicationKey ].pluginConfig = arguments.pluginConfig; 
	}
	
	public any function getPluginConfig() {
		return application[ variables.framework.applicationKey ].pluginConfig; 
	}
	
	public any function getSubsystemBaseURL( string subsystem="admin") {
		return variables.subsystems[ arguments.subsystem ].baseURL; 
	}
	
	// Start: Standard Application Functions. These are also called from the fw1EventAdapter.
	public void function setupApplication(any $) {
		// Check to see if the base application has been loaded, if not redirect then to the homepage of the site.
		if( !structKeyExists(application, "appinitialized") || application.appinitialized == false) {
			location(url="http://#cgi.HTTP_HOST#", addtoken=false);
		}
		
		// Setup Default Data... This is only for development and should be moved to the update function of the plugin once rolled out.
		var dataPopulator = new Slatwall.com.utility.DataPopulator();
		dataPopulator.loadDataFromXMLDirectory(xmlDirectory = ExpandPath("/plugins/Slatwall/config/DBData"));
		
		var serviceFactory = "";
		var rbFactory = "";
		var xml = "";
		var xmlPath = "";

	    if ( not structKeyExists(request,"pluginConfig") or request.pluginConfig.getPackage() neq variables.framework.applicationKey){
		  	include "plugin/config.cfm";
		}
	    setPluginConfig(request.PluginConfig);
		xmlPath = "#expandPath( '/plugins' )#/#getPluginConfig().getDirectory()#/config/coldspring.xml";
		xml = FileRead("#xmlPath#"); 
		
		
		// Parse the xml and replace all [plugin] with the actual plugin mapping path.
	  	xml = replaceNoCase( xml, "[plugin]", "plugins.#getPluginConfig().getDirectory()#.", "ALL");
		
		if (getPluginConfig().getSetting("Integration") neq "Internal"){
			xml = replaceNoCase( xml, "[integration]", "#getPluginConfig().getSetting('Integration')#.", "ALL");
		}
		else {
			xml = replaceNoCase( xml, "[integration]", "", "ALL");
		}
		
		// Build Coldspring factory & Set in FW/1
		serviceFactory=createObject("component","coldspring.beans.DefaultXmlBeanFactory").init();
		serviceFactory.loadBeansFromXmlRaw( xml );
		serviceFactory.setParent(application.servicefactory);
		getpluginConfig().getApplication().setValue( "serviceFactory", serviceFactory );
		setBeanFactory(request.PluginConfig.getApplication().getValue( "serviceFactory" ));
		
		// Setup run Setting Service reload config
		getBeanFactory().getBean("settingService").reloadConfiguration();
		
		// Build RB Factory
		rbFactory= new mura.resourceBundle.resourceBundleFactory(application.settingsManager.getSite('default').getRBFactory(),"#getDirectoryFromPath(getCurrentTemplatePath())#resourceBundles/");
		getpluginConfig().getApplication().setValue( "rbFactory", rbFactory);
		
		// Set this in the application scope to be used later
		application[ variables.framework.applicationKey ].fw = this;
	}
	
	public void function setupRequest() {
		// Set default mura session variables when needed
		param name="session.rb" default="en";
		param name="session.locale" default="en";
		param name="session.siteid" default="default";
		param name="session.dashboardSpan" default="30";
		if(!structKeyExists(session, "datekey")) {
			getpluginConfig().getApplication().getValue( "rbFactory" ).getUtils().setJSDateKeys();
			session.datekey = getpluginConfig().getApplication().getValue( "rbFactory" ).getUtils().getJSDateKey();
		}
		
		// Setup Slatwall Session
		getBeanFactory().getBean("sessionService").setupSessionRequest();
		
		// Look for mura Scope.  If it doens't exist add it.
		if (!structKeyExists(request.context,"$")){
			request.context.$=getBeanFactory().getBean("muraScope").init(session.siteid);
		}
		
		// Make sure that the mura Scope has a siteid.  If it doesn't then use the session siteid
		if(request.context.$.event('siteid') == "") {
			request.context.$.event('siteid', session.siteid);
		}
		
		// Setup Base URL's for each subsystem
		variables.subsystems.admin.baseURL="http://#cgi.http_host#/plugins/#getPluginConfig().getDirectory()#/";
		variables.subsystems.frontend.baseURL = "http://#request.context.$.siteConfig().getDomain()#/";
		if(request.context.$.globalConfig().getSiteIDInURLS()) {
			variables.subsystems.frontend.baseURL &= "#request.context.$.siteConfig('siteid')#/"; 
		}
		if(request.context.$.globalConfig().getIndexFileInURLS()) {
			variables.subsystems.frontend.baseURL &= "index.cfm";
		}
		
		// Create SlatwallScope and add it to the muraScope
		request.context.$.setCustomMuraScopeKey("slatwall", new Slatwall.com.utility.SlatwallScope());
		
		// Run subsytem specific logic.
		if(isAdminRequest()) {
			controller("admin:BaseController.subSystemBefore");
		} else {
			controller("frontend:BaseController.subSystemBefore");
		}
	}

	
	// End: Standard Application Functions. These are also called from the fw1EventAdapter.

	// Helper Functions
	public boolean function isAdminRequest() {
		return not structKeyExists(request,"servletEvent");
	}
	
	public string function getExternalSiteLink(required String Address) {
		return buildURL(action='external.site', queryString='es=#arguments.Address#');
	}
	
	public boolean function secureDisplay(required string action, boolean testing=false) {
		var hasAccess = false;
		
		var permissionName = UCASE("PERMISSION_#getSubsystem(arguments.action)#_#getSection(arguments.action)#_#getItem(arguments.action)#");
		
		if(request.context.$.currentUser().getS2()) {
			hasAccess = true;
		} else if (listLen( request.context.$.currentUser().getMemberships() ) >= 1) {
			var rolesWithAccess = "";
			if(find("save", permissionName)) {
				rolesWithAccess = application.slatwall.pluginConfig.getApplication().getValue("serviceFactory").getBean("settingService").getPermissionValue(permissionName=replace(permissionName, "save", "edit")); 
				listAppend(rolesWithAccess, application.slatwall.pluginConfig.getApplication().getValue("serviceFactory").getBean("settingService").getPermissionValue(permissionName=replace(permissionName, "save", "update")));
			} else {
				rolesWithAccess = application.slatwall.pluginConfig.getApplication().getValue("serviceFactory").getBean("settingService").getPermissionValue(permissionName=permissionName);
			}
			
			for(var i=1; i<= listLen(rolesWithAccess); i++) {
				if( find( listGetAt(rolesWithAccess, i), request.context.$.currentUser().getMemberships() ) ) {
					hasAccess=true;
					break;
				}
			}
		}
		return hasAccess;
	}
	
	// Override autowire function from fw/1 so that properties work
	private void function autowire(cfc, beanFactory) {
		var key = 0;
		var property = 0;
		var args = 0;
		var meta = getMetaData(arguments.cfc); 
		
		for(key in arguments.cfc) {
			if(len(key) > 3 && left(key,3) is "set") {
				property = right(key, len(key)-3);
				if(arguments.beanFactory.containsBean(property)) {
					evaluate("arguments.cfc.#key#(#arguments.beanFactory.getBean(property)#)");
				}
			}
		}
		if(isDefined("meta.accessors") && meta.accessors == true) {
			for(var i = 1; i <= arrayLen(meta.properties); i++) {
				if(arguments.beanFactory.containsBean(meta.properties[i].name)) {
					evaluate("arguments.cfc.set#meta.properties[i].name#(arguments.beanFactory.getBean(meta.properties[i].name))");
				}
			}
		}
	}
	
	/**
	/*@hint used to populate beans from the request context. FW1 method overriden to set empty values to null
	
	public any function populate(required any cfc, string keys="", boolean trustKeys=false, boolean trim=false, boolean acceptEmptyValues=true) {
		var key = 0;
		var property = 0;
		var trimproperty = 0;
		var args = 0;
		
		if(arguments.keys == "") {
			if(arguments.trustKeys) {
				// assume everything in the request context can be set into the CFC
				for(property in request.context) {
					key = "set" & property;
					try {
						args = {};
						args[property] = request.context[ property ];
						if(arguments.trim && isSimpleValue(args[property])) {
							args[property] = trim( args[property] );
						}
						if(len(args[property]) > 0 || arguments.acceptEmptyValues) {
							evaluate("arguments.cfc.#key#(argumentCollection=args)");
						} else if( len(args[property]) == 0 && !arguments.acceptEmptyValues ) {
							evaluate("arguments.cfc.#key#(javacast('null',''))");
						}
					} catch(any e) {
						onPopulateError( arguments.cfc, property, request.context );
					}
				}
			} else {
				for(key in arguments.cfc) {
					if(len(key) > 3 and left(key,3) == "set") {
						property = right( key, len( key ) - 3 );
						if(structKeyExists( request.context, property )) {
							args = structNew();
							args[ property ] = request.context[ property ];
							if(arguments.trim and isSimpleValue( args[property] )) {
								args[property] = trim( args[property] );
							}
							if(len(args[property]) > 0 || arguments.acceptEmptyValues) {
								evaluate("arguments.cfc.#key#(argumentCollection=args)");
							} else if( len(args[property]) == 0 && !arguments.acceptEmptyValues ) {
								evaluate("arguments.cfc.#key#(javacast('null',''))");
							}
						}
					}
				}	
			}
		} else {
			for(var i=1; i<=listLen(arguments.keys); i++) {
				trimProperty = trim(listGetAt(arguments.keys,i));
				key = "set" & trimProperty;
				if(structKeyExists( arguments.cfc, key ) || arguments.trustKeys) {
					if(structKeyExists( request.context, trimProperty )) {
						args = {};
						args[ trimProperty ] = request.context[ trimProperty ];
						if(arguments.trim && isSimpleValue( args[trimProperty] )) {
							args[trimProperty] = trim( args[trimProperty] );
						}
						if(len(args[trimproperty]) > 0 || arguments.acceptEmptyValues) {
							evaluate("arguments.cfc.#key#(argumentCollection=args)");
						} else if( len(args[property]) == 0 && !arguments.acceptEmptyValues ) {
							evaluate("arguments.cfc.#key#(javacast('null',''))");
						}
					}
				}
			}
		}
		return arguments.cfc;
	}*/

	public string function buildURL(required string action, string path="#variables.framework.baseURL#", string queryString="") {
		arguments.path = getSubsystemBaseURL(getSubsystem(arguments.action));
		return super.buildURL(argumentCollection=arguments);
	}
}
