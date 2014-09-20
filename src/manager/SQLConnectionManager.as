package manager
{
  import com.adobe.nativeExtensions.Networkinfo.NetworkInfo;
  
  import flash.data.EncryptedLocalStore;
  import flash.data.SQLConnection;
  import flash.data.SQLResult;
  import flash.data.SQLStatement;
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.events.SQLErrorEvent;
  import flash.events.SQLEvent;
  import flash.events.SecurityErrorEvent;
  import flash.filesystem.File;
  import flash.net.NetworkInfo;
  import flash.net.URLLoader;
  import flash.net.URLLoaderDataFormat;
  import flash.net.URLRequest;
  import flash.net.URLRequestMethod;
  import flash.net.URLVariables;
  import flash.utils.ByteArray;
  import flash.utils.getDefinitionByName;
  
  import mx.collections.ArrayCollection;
  
  import objects.YoutubeVideo;
  
  public class SQLConnectionManager extends EventDispatcher
  {
    private static var _instance:SQLConnectionManager;
    private static const URL:String = "file.php";
    
    private var connection:SQLConnection;
    private var statement:SQLStatement;
    private var query:String;
    private var last_update:String;
    private var videosRemaining:int=0;
    private var limit_date:String;
    
    public var videos:ArrayCollection;
    public var old_date:String;
    public var end_data:Boolean = false;
    
    public static function get instance() : SQLConnectionManager
    {
      if ( _instance == null )
        _instance = new SQLConnectionManager();
      
      return _instance;
    }
    
    public function init():void
    {
      createDatabase();
    }
    
    private function createDatabase():void
    {
      // This creates an SQLConnection object , which can be accessed publicly so that event listeners can be defined for it
      connection = new SQLConnection();
      
      var databaseFile:File = File.applicationStorageDirectory.resolvePath("database.db");
      connection.addEventListener(SQLEvent.OPEN, openDatabaseHandler);
      connection.openAsync(databaseFile);
    }
    
    private function isConnectionOn() : Boolean
    {
      var vNetworkInterfaces:Object;
      if (flash.net.NetworkInfo.isSupported)
      { 
        vNetworkInterfaces = flash.net.NetworkInfo.networkInfo.findInterfaces();
      } 
      else 
      { 
        vNetworkInterfaces = com.adobe.nativeExtensions.Networkinfo.NetworkInfo.networkInfo.findInterfaces();
      }
      
      var hasWifi : Boolean = false;
      var hasMobile : Boolean = false;
      var networkInterface : Object;
      
      for each (networkInterface in vNetworkInterfaces)
      { 
        if ( networkInterface.active && networkInterface.name.toLowerCase() == "wifi" ) hasWifi = true;
        if ( networkInterface.active && networkInterface.name.toLowerCase() == "mobile" ) hasMobile = true;
      }
      
      return hasWifi || hasMobile;
    }
    
    private function getStoredDate() : void
    {
      var storedValue : ByteArray = EncryptedLocalStore.getItem("last_update");
      if(storedValue != null)
        last_update = storedValue.toString();
      else
        last_update = null;
    }
    
    private function openDatabaseHandler(event:SQLEvent):void
    {
      refresh();
    }
    
    public function refresh(limit : Boolean = false) : void
    {
      getStoredDate();
      
      if(isConnectionOn())
      {
        if(last_update == null)
        {
          createTables();
        }
        else
        {
          var last_date : Date = sqlToFlash(last_update);
          last_date.date += 1;
          if(limit)
            limit_date = dateToString(last_date);
          var today : Date = new Date;
          var today_date : Date = new Date(today.fullYear,today.month,today.date);
          last_update = dateToString(today_date);
          if(last_date.time <= today_date.time)
          {
            loadDataBetweenDates(dateToString(last_date),last_update);
          }
          else if(videos && videos.length > 0)
          {
            instance.dispatchEvent(new Event(Event.COMPLETE));
          }
          else
          {
            loadDataFromLocalDatabase();
          }
        }
      }
      else if(last_update && (!videos || videos.length == 0))
      {
        loadDataFromLocalDatabase();
      }
      else
      {
        instance.dispatchEvent(new Event(Event.COMPLETE));
      }
    }
    
    private function createTables() : void
    {
      statement = new SQLStatement();
      statement.sqlConnection = connection;
      statement.addEventListener(SQLEvent.RESULT, createTableResult);
      statement.addEventListener(SQLErrorEvent.ERROR,onSQLError);
      query = "CREATE TABLE IF NOT EXISTS videos (id INTEGER PRIMARY KEY, video_id TEXT UNIQUE, title TEXT, duration INTEGER, date TEXT, category TEXT, type TEXT)";
      statement.text = query;
      statement.execute();
    }
    
    private function createTableResult(event:SQLEvent):void
    {
      if(event)
      {
        statement.removeEventListener(SQLErrorEvent.ERROR, onSQLError);
        statement.removeEventListener(SQLEvent.RESULT, createTableResult);
        statement = null;  
      }
      
      var today : Date = new Date;
      last_update = dateToString(today);
      var lastDate : Date = new Date(today);
      lastDate.month -= 1;
      
      loadDataBetweenDates(dateToString(lastDate),last_update);
    }
    
    private function loadDataBetweenDates(fromDate : String,toDate : String) : void
    {
      var randomParam:String = "?p=" + Math.floor(Math.random() * (10000000));
      var loader : URLLoader = new URLLoader();
      loader.dataFormat = URLLoaderDataFormat.TEXT;
      var vars : URLVariables = new URLVariables;
      vars.from = fromDate;
      vars.to = toDate;
      var request : URLRequest = new URLRequest(URL + randomParam);
      request.method = URLRequestMethod.POST;
      request.data = vars;
      loader.addEventListener(Event.COMPLETE, onSQLDataLoaded);
      loader.addEventListener(IOErrorEvent.IO_ERROR, onSQLFailedToLoad);
      loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSQLFailedToLoad);
      loader.load(request);
    }
    
    private function onSQLFailedToLoad(e:Event):void 
    {
      trace("onSQLFailedToLoad error=" + e.toString());
      var loader : URLLoader = e.target as URLLoader;
      loader.removeEventListener(Event.COMPLETE, onSQLDataLoaded);
      loader.removeEventListener(IOErrorEvent.IO_ERROR, onSQLFailedToLoad);
      loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSQLFailedToLoad);
      createTableResult(null);
    }
    
    private function onSQLDataLoaded(e:Event):void 
    {
      var loader : URLLoader = e.target as URLLoader;
      loader.removeEventListener(Event.COMPLETE, onSQLDataLoaded);
      loader.removeEventListener(IOErrorEvent.IO_ERROR, onSQLFailedToLoad);
      loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSQLFailedToLoad);
      
      var remoteVideos : Array = JSON.parse(loader.data) as Array;
      var length:int = remoteVideos.length;
      var video : YoutubeVideo;
      videos = new ArrayCollection;
      for(videosRemaining; videosRemaining < length; videosRemaining++)
      {
        video = new YoutubeVideo(remoteVideos[videosRemaining]);
        videos.addItem(video);
      }
      videosRemaining = 0;
      saveDataToLocalDatabase();
    }
    
    private function saveDataToLocalDatabase() : void
    {
      var video : YoutubeVideo = videos[videosRemaining] as YoutubeVideo;
      statement = new SQLStatement();
      statement.sqlConnection = connection;
      query = "INSERT INTO videos (video_id, title, duration, date, category, type) VALUES (:video_id,:title,:duration,:date,:category,:type)";
      statement.text = query;
      statement.parameters[":video_id"] = video.video_id;
      statement.parameters[":title"] = video.title;
      statement.parameters[":duration"] = video.duration;
      statement.parameters[":date"] = video.date;
      statement.parameters[":category"] = video.category;
      statement.parameters[":type"] = video.type;
      statement.addEventListener(SQLEvent.RESULT, insertResult);
      statement.addEventListener(SQLErrorEvent.ERROR,onSQLError);
      statement.execute();
    }
    
    private function insertResult(event:SQLEvent):void
    {
      statement.removeEventListener(SQLErrorEvent.ERROR, onSQLError);
      statement.removeEventListener(SQLEvent.RESULT, insertResult);
      statement = null;
      videosRemaining++;
      if(videosRemaining < videos.length)
        saveDataToLocalDatabase();
      else
      {
        videos.removeAll();
        var ba : ByteArray = new ByteArray;
        ba.writeUTFBytes(last_update);
        EncryptedLocalStore.setItem("last_update",ba);
        loadDataFromLocalDatabase();
      }
    }
    
    public static function sqlToFlash(date:String):Date
    {
      var scatDate:Array = date.split('-');
      var year:Number = scatDate[0];
      var month:Number = scatDate[1]-1;
      var day:Number = scatDate[2];
      var finalDate:Date = new Date(year,month,day);
      return finalDate;
    }
    
    public static function dateToString(date:Date):String
    {
      var result : String;
      var month : String = date.month + 1 > 9 ? "" + (date.month + 1) : "0" + (date.month + 1);
      var day : String = date.date > 9 ? "" + date.date : "0" + date.date;
      result = date.fullYear + "-" + month + "-" + day;
      return result;
    }
    
    public function loadDataFromLocalDatabase(first_date : String = null, second_date : String = null) : void
    {
      if(!first_date && !second_date)
      {
        second_date = last_update;
        if(limit_date)
        {
          first_date = limit_date;
        }
        else
        {
          var date : Date = sqlToFlash(last_update);
          date.date -= 7;
          first_date = dateToString(date);  
        }
      }
      statement = new SQLStatement();
      statement.sqlConnection = connection;
      statement.addEventListener(SQLEvent.RESULT, selectResult);		
      statement.addEventListener(SQLErrorEvent.ERROR,onSQLError);
      query = "SELECT * FROM videos WHERE date BETWEEN '" + first_date + "' AND '" + second_date + "' ORDER BY date DESC";
      statement.text = query;
      statement.execute();
    }
    
    private function selectResult(e:SQLEvent) : void
    {
      statement.removeEventListener(SQLErrorEvent.ERROR, onSQLError);
      statement.removeEventListener(SQLEvent.RESULT, selectResult);
      limit_date = null;
      var result : SQLResult = statement.getResult();
      if(!result.data)
      {
        end_data = true;
        instance.dispatchEvent(new Event(Event.COMPLETE));
        return;
      }
      
      var i : int;
      var length : int = result.data.length;
      var video : YoutubeVideo;
      var temp : ArrayCollection = new ArrayCollection;
      for(i = 0; i < length; i++)
      {
        video = new YoutubeVideo(result.data[i]);
        temp.addItem(video);
      }
      old_date = (temp[i-1] as YoutubeVideo).date;
      if(!videos)
        videos = new ArrayCollection;
      videos.addAll(finalizeVideos(temp));
      statement.removeEventListener(SQLErrorEvent.ERROR, onSQLError);
      statement.removeEventListener(SQLEvent.RESULT, selectResult);
      statement = null;
      instance.dispatchEvent(new Event(Event.COMPLETE));
    }
    
    private function finalizeVideos(temp : ArrayCollection) : ArrayCollection
    {
      var video : YoutubeVideo;
      var video_date : Date;
      var date : Date;
      var i : int;
      var length : int = temp.length;
      var result : ArrayCollection = new ArrayCollection;
      for(i = 0; i < length; i++)
      {
        video = temp[i] as YoutubeVideo;
        if(!date)
        {
          date = sqlToFlash(video.date);
          result.addItem(date);
        }
        else
        {
          video_date = sqlToFlash(video.date);
          if(video_date.time != date.time)
          {
            date = new Date(video_date);
            result.addItem(date);
          }
        }
        result.addItem(video);
      }
      
      return result;
    }
    
    private function onSQLError(event:SQLErrorEvent):void
    {
      trace(event.toString());
      statement.removeEventListener(SQLErrorEvent.ERROR, onSQLError);
      statement.removeEventListener(SQLEvent.RESULT, createTableResult);
      statement.removeEventListener(SQLEvent.RESULT, insertResult);
      statement.removeEventListener(SQLEvent.RESULT, selectResult);
    }
    
  }
}