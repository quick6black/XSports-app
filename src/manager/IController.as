package manager
{
	import spark.components.Application;

	public interface IController
	{
		
		function applicationReady(application:Application):void;
		
	}
}