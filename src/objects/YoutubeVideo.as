package objects
{
  public class YoutubeVideo
  {
    public var video_id : String;
    public var title : String;
    public var duration : int;
    public var category : String;
    public var type : String;
    public var date : String;
    
    public function YoutubeVideo(value : Object) : void
    {
      video_id = value.video_id;
      category = value.category;
      date = value.date;
      type = value.type;
      title = value.title;
      duration = value.duration;
    }
  }
}