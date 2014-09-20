package manager
{	
  import spark.components.Application;
  
  import views.PhoneView;
  
  public class PhoneController implements IController
  {
    
    private var phoneMainView:PhoneView = new PhoneView();
    
    public function PhoneController()
    {}
    
    public function applicationReady(application:Application):void 
    {		
      application.addElement( phoneMainView );
    }
    
  }
}