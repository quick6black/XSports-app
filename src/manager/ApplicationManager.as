package manager
{
  import flash.display.StageDisplayState;
  import flash.events.Event;
  import flash.system.Capabilities;
  
  import mx.core.FlexGlobals;
  
  import spark.components.Application;
  
  public class ApplicationManager
  {
    private static var _instance:ApplicationManager;
    
    public var appDensity:Number;
    public var appDPI:Number;
    public var screenDPI:Number;
    
    public static function get instance():ApplicationManager 
    {
      if(_instance == null)
        _instance = new ApplicationManager();
      
      return _instance;
    }
    
    public static function isAndroid() : Boolean
    {
      return (Capabilities.version.substr(0,3) == "AND");
    }
    
    private var controller:IController;
    
    private var application:Application;
    
    private var _isTablet:Boolean = false;
    
    private var _isPhone:Boolean = false;
    
    /** Constructor that uses a singletonkey, so this class must be referenced
     * through the getInstance static method; thus limiting only one instance
     * to be created */
    public function init():void
    {      
      // Get a reference to the top level application
      application = FlexGlobals.topLevelApplication as Application;
      
      appDensity = FlexGlobals.topLevelApplication.runtimeDPI;
      appDPI = FlexGlobals.topLevelApplication.applicationDPI;
      screenDPI = Capabilities.screenDPI;
      
      // Listen for the "Added To Stage" event from the application
      // This will signal that we can begin measuring the stage
      application.addEventListener(Event.ADDED_TO_STAGE, applicationAddedToStage);
    }
    
    public function applicationAddedToStage(event:Event):void 
    {      
      application.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
      
      if(screenIsGreaterThan6Inches())
      {
        _isTablet = true;
        _isPhone = false; 
      }
      else
      {
        _isTablet = false;
        _isPhone = true;  
      }
      
      controller = new PhoneController();
      controller.applicationReady(application);
    }
    
    /** Measures the screen size, and then returns true/false based on whether
     * the width or height of the screen is greater than 5 inches. */
    protected function screenIsGreaterThan6Inches():Boolean {
      
      // Find the physical size in inches, using the devices real DPI
      var width:Number = application.stage.stageWidth / application.runtimeDPI;
      var height:Number = application.stage.stageHeight / application.runtimeDPI;
      
      //this will resolve to the physical size in inches...
      //if greater than 5 inches, assume its a tablet
      return ( width >= 6 || height >= 6);
    }
    
    [Bindable(event="deviceTypeSet")]
    public function get isTablet():Boolean {
      return _isTablet;
    }
    
    [Bindable(event="deviceTypeSet")]
    public function get isPhone():Boolean {
      return _isPhone;
    }
  }
}