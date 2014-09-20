package manager
{
  import spark.components.Application;
  
  import views.tablet.TabletView;
  
  public class TabletController implements IController
  {
    
    private var tabletMainView:TabletView = new TabletView();
    
    public function TabletController()
    {}
    
    public function applicationReady(application:Application):void 
    {
      application.addElement( tabletMainView );	
    }
    
  }
}