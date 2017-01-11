package  
{
	import flash.display.MovieClip;
	import flash.events.*;
	import flash.media.*;
	import flash.net.*;
	import flash.system.*;
	import flash.utils.*;
	import flash.external.ExternalInterface;
	
	import events.*;
	
	/**
	 * ...
	 * @author Аракчеев В.А.
	 */
	
	public class Main extends MovieClip
	{		
		// Сервер вещания
		private const rtmpServer:String = "rtmp://184.72.239.149/live";
		//private const rtmpServer:String = "rtmp://xmpp.directual.com/live";

		// высота размера кадра
		private const CAM_HEIGHT:int = 220;
		
		// Таймер на 2 сек
		private var _timer:Timer = null;
		
		// Прелоадер
		private var _preloader:CircleSlicePreloader = null;
		
		// Мультимедиа
		private var camera:Camera = null;
		private var microphone:Microphone = null;
		
		// Потоки
		private var netConnection:NetConnection = null;
		
		// Контейнер записи
		private var recordContainer:StreamRecorder = null;
		
		// Контейнер воспроизведения
		private var playContainer:StreamPlayer = null;
				
		// Состояния
		private var isRecording:Boolean = false;
		private var isPlayin:Boolean = false;
		
		private var _isReady:Boolean = false;
		
		// Имя последнего записанного потока
		private var streamName:String = null;
		
		private var _reccount:Number = 3;
		
		public function Main() 
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			
			// Прелоадер
			_preloader = new CircleSlicePreloader(12,12);
			_preloader.x = this.width/2;
			_preloader.y = this.height/2;			
			preloaderContainer.addChild(_preloader);
			
			//Кнопка разрешения доступа к камере
			btnAccept.addEventListener(MouseEvent.CLICK, onAcceptClick);
			removeChild(btnAccept);
			
			// Подключаем поток
			netConnection = new NetConnection();
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
			netConnection.connect(rtmpServer);
			netConnection.client = { 'onBWDone': onBWDone };
			
			// Кнопки
			with (controlPanel)
			{
				btnSave.addEventListener(MouseEvent.CLICK, onSave);
				btnSave.visible = false;
				
				btnPlay.addEventListener(MouseEvent.CLICK, onPlay);
				btnPlay.visible = false;
				
				btnStop.addEventListener(MouseEvent.CLICK, onStop);
				btnStop.x = 0;
				
				btnRec.addEventListener(MouseEvent.CLICK, onRec);
				
				// Выключаем кнопки
				enableButtons(false);
			}
			
		}
		
	
		// Останов
		private function onStop(e:MouseEvent):void 
		{			
			// Шла запись
			if (isRecording)
			{
				// Отрубаем таймер (если включен был)
				if (_timer != null)
				{
					_timer.stop();
					_timer.removeEventListener(TimerEvent.TIMER, onTimer);
					_timer = null;
					
					PutMsg("");
				}
			
				// 1. Убрать все кнопки
				with (controlPanel)
				{
					btnSave.visible = false;
					btnPlay.visible = false;
					btnStop.visible = false;
					btnRec.visible = false;
					
					// Расянуть окно сообщений
					messagePanel.x = 0;
					messagePanel.width = this.width;
				}
				
				// Показать лоадер
				preloaderContainer.addChild(_preloader);
				
				// Перехватываем сообщение
				recordContainer.addEventListener(PublishEvent.BUFFER_EMPTY, onBufferEmpty);
				// Останов публикации
				recordContainer.stopPublish();
				
				// Скидываем флаг
				isRecording = false;
			}
			
			// Если было проигрывание
			if (isPlaying)
			{
				cameraContainer.visible = true;
				streamContainer.visible = false;
				
			// Удалить прелоадер
			if (_preloader.parent)
				preloaderContainer.removeChild(_preloader);
				
				// Показываем кнопки	
				with (controlPanel)
					{
						btnSave.visible = true;
						btnPlay.visible = true;
						btnRec.visible = true;
						
						// Расянуть окно сообщений
						messagePanel.x = 186;
						messagePanel.width = 213.5;
					}
				
				PutMsg("");	
				
				// Останавливаем видео проигрывание
				playContainer.stopVideo();
			
				//isPlaying = false;
			}
		}
		
		// Данные из буфера отправлены
		private function onBufferEmpty(e:PublishEvent):void 
		{
			// Удаляем слухач
			recordContainer.removeEventListener(PublishEvent.BUFFER_EMPTY, onBufferEmpty);
			
			// Удалить прелоадер
			if (_preloader.parent)
				preloaderContainer.removeChild(_preloader);
				
			// Показываем кнопки	
			with (controlPanel)
				{
					btnSave.visible = true;
					btnPlay.visible = true;
					btnRec.visible = true;
					
					// Расянуть окно сообщений
					messagePanel.x = 186;
					messagePanel.width = 213.5;
				}
			
			PutMsg("");	
		}
		
		// Начало записи
		private function onRec(e:MouseEvent):void 
		{
			if (!_isReady)
				return;
			
			_reccount = 3;
				
			// Отключаем кнопки (если до этого была запись)
			with (controlPanel)
			{
				btnSave.visible = false;
				btnPlay.visible = false;
					
				btnRec.visible = false;
				btnStop.visible = true;	
				
				// Расянуть окно сообщений
				messagePanel.x = 62;
				messagePanel.width = 338;
			}
			
			cameraContainer.visible = true;
			streamContainer.visible = false;
			
			PutMsg("Подготовка к записи - " + _reccount.toString());
			
			_timer = new Timer(1000);
			_timer.addEventListener(TimerEvent.TIMER, onTimer);
			_timer.start();
			
			onTimer(null);
			
			// Начало записи
			recordContainer.startPublish();
			// считываем имя потока
			streamName = recordContainer.streamName;
			
			isRecording = true;			
		}
		
		private function onTimer(e:TimerEvent):void 
		{
			_reccount--;
			
			if (_reccount == 0)
			{
				// Удаляем слухач
				_timer.removeEventListener(TimerEvent.TIMER, onTimer);
				PutMsg("Запись");
				return;
			}
			
			PutMsg("Подготовка к записи - " + _reccount.toString());
		}
		
		// Проигрывание данных
		private function onPlay(e:MouseEvent):void 
		{
			if (streamName == null)
				return;
			
			if (!_isReady)	
				return;
				
			cameraContainer.visible = false;
			streamContainer.visible = true;
			
			with (controlPanel)
			{
				btnSave.visible = false;
				btnRec.visible = false;
				btnPlay.visible = false;
				btnStop.visible = true;	
				
				// Расянуть окно сообщений
				messagePanel.x = 62;
				messagePanel.width = 338;
			}
			
			playContainer.addEventListener(PublishEvent.PLAY_STOP, onPlayStop);
			//Буфер заполнен
			playContainer.addEventListener(PublishEvent.BUFFER_FULL, onFullBuffer);
			// Буфер пуст			
			playContainer.addEventListener(PublishEvent.BUFFER_EMPTY, onEmptyBuffer);
			// Начало воспроизведения
			playContainer.addEventListener(PublishEvent.PLAY_START, onPlayStart);
			
			//trace("SN: " + streamName)
			
			// Запуск проигрывания
			playContainer.playVideo(streamName);

			PutMsg("Проигрывание");
			
			isPlayin = true;
		}
		
		private function onPlayStart(e:PublishEvent):void 
		{
			if(!_preloader.parent)
				preloaderContainer.addChild(_preloader);
		}
		
		private function onEmptyBuffer(e:PublishEvent):void 
		{
			if(!_preloader.parent)
				preloaderContainer.addChild(_preloader);
		}
		
		private function onFullBuffer(e:PublishEvent):void 
		{
			// Удалить прелоадер
			if (_preloader.parent)
				preloaderContainer.removeChild(_preloader);
		}
		
		// Закончилось воспроизведение видео
		private function onPlayStop(e:PublishEvent):void 
		{
			playContainer.removeEventListener(PublishEvent.PLAY_STOP, onPlayStop);
			
			// Показываем кнопки	
			with (controlPanel)
				{
					btnSave.visible = true;
					btnPlay.visible = true;
					btnRec.visible = true;
					
					// Расянуть окно сообщений
					messagePanel.x = 186;
					messagePanel.width = 213.5;
				}

			PutMsg("");	
			
			// Останавливаем видео проигрывание
			playContainer.stopVideo();
			
			isPlayin = false;
		}
		
		// Сохранение данных
		private function onSave(e:MouseEvent):void 
		{
			if (!_isReady)
				return;
				
			try 
			{
				ExternalInterface.call("record_complete", recordContainer.streamName);
			} 
			catch (error:Error) 
			{
				PutMsg("Ошибка JavaScript!");
			}
		}
				
		private function onAcceptClick(e:MouseEvent):void 
		{
			// Выводим панель
			Security.showSettings(SecurityPanel.PRIVACY);
		}
		
		// Заглушка
		private function onBWDone():void
		{		
		}
		
		private function PutMsg(message:String):void
		{
			controlPanel.messagePanel.msgControl.text = message;
		}
		
		private function onConnectionStatus(info:NetStatusEvent):void 
		{
			switch(info.info.code)
			{
				// Попытка подключения удалась.
				case "NetConnection.Connect.Success":
				
					// Удаляем прелоадер	
					if (_preloader.parent)
						preloaderContainer.removeChild(_preloader);
					
					// Настройка камеры
					if (!setupCamera(CAM_HEIGHT))
						return;
				
					// Смотрим о доступности камеры
					if (camera.muted == true)
					{
						// При ошибке
						
						// Показать панель настроек
						Security.showSettings(SecurityPanel.PRIVACY);
						
						// Выдаем сообщение об ошибке
						PutMsg("Доступ к камере запрещен!");
						
						// Выводим кнопку						
						addChild(btnAccept);
						return;
					}
					
					// Настройка микрофона
					if (!setupMicrophone())
						return;
				
					// Смотрим о доступности микрофона
					if (microphone.muted == true)
					{
						// При ошибке
						
						// Показать панель настроек
						Security.showSettings(SecurityPanel.PRIVACY);
						
						// Выдаем сообщение об ошибке
						PutMsg("Доступ к микрофону запрещен!");
						
						// Выводим кнопку
						addChild(btnAccept);
						return;
					}
					
					// Очистка окна сообщений
					PutMsg("");
					
					// Инициализация камеры
					initVideo();
					
					break;
					
				// При попытке подключения отсутствовали права на доступ к приложению.
				case "NetConnection.Connect.Rejected":
					
					PutMsg("Нет прав на доступ к приложению!");
					break;
					
				// Попытка подключения не удалась.
				case "NetConnection.Connect.Failed":
				
				// Удаляем прелоадер	
					if (_preloader.parent)
						preloaderContainer.removeChild(_preloader);	

					controlPanel.btnRec.enabled = false;
					PutMsg("Ошибка при подключении к серверу!");
					
					break;
					
				// Подключение успешно разорвано.	
				case "NetConnection.Connect.Closed":	
					
					PutMsg("Подключение разорвано сервером!");
					break;
			}
		}
		
		// Установки микрофона
		private function setupMicrophone():Boolean 
		{
			// Смотрим микрофон в системе
			microphone = Microphone.getMicrophone();
			
			if (microphone == null) 
			{
				PutMsg("Не найден микрофон!");
				return false;
			}

			// Сообщения статуса
			microphone.addEventListener(StatusEvent.STATUS, onMicStatus);
			
			microphone.codec = SoundCodec.SPEEX;
			microphone.rate = 44;
			microphone.gain = 50;
			microphone.setSilenceLevel(0);
			microphone.encodeQuality = 10;
			microphone.framesPerPacket = 1;
			microphone.setUseEchoSuppression(true);
			microphone.setLoopBack(true);
			microphone.setLoopBack(false);
			
			// Включение Voice Activity Detection
			if (microphone['enableVAD']) 
				microphone['enableVAD'] = true;
			
			return true;
		}
		
		// Статус от микрофона
		private function onMicStatus(e:StatusEvent):void 
		{
			if(e.code == "Microphone.Unmuted")
			{
				if (btnAccept.parent)
					removeChild(btnAccept);
				
				PutMsg("");
				initVideo();
			}
			else
			{
				PutMsg("Доступ к микрофону запрещен!");
				addChild(btnAccept);
				
				recordContainer = null;
				playContainer = null;
				_isReady = false;
				
				enableButtons(false);
			}
		}
		
		private function enableButtons(enable:Boolean = true):void
		{
			with (controlPanel)
			{
				btnRec.enabled = enable;
				btnPlay.enabled = enable;
				btnSave.enabled = enable;
				btnStop.enabled = enable;				
			}
		}
		
		private function setupCamera(height:int):Boolean 
		{
			// Запрос камеры
			camera = Camera.getCamera();
			
			// Если не найдена - выход
			if (camera == null) 
			{
				PutMsg("Не найдена камера!");
				return false;
			}
			
			// Статус
			camera.addEventListener(StatusEvent.STATUS, onCameraStatus);
			
			// Коэф. соотношения сторон = 4/3
			var aspect:Number = 4/3;
			
			// Ширина (~1 - обнуляет последний бит - размеры должны быть степень 2ки)
			var width:int = (int(aspect * height) + 1) & ~1;

			// Установка параметров
			camera.setMode(width, height, 25, false);
			camera.setQuality(65536 * 2, 0);			
			camera.setKeyFrameInterval(2);
			camera.setLoopback(true);
			
			return true;
		}
		
		// Статус от камеры
		private function onCameraStatus(e:StatusEvent):void 
		{
			if (e.code == "Camera.Unmuted")
			{
				if(btnAccept.parent)
					removeChild(btnAccept);
					
				PutMsg("");
				
				initVideo();
			}
			else
			{
				PutMsg("Доступ к камере запрещен!");
				addChild(btnAccept);
				
				recordContainer = null;
				playContainer = null;
				_isReady = false;
				enableButtons(false);
			}				
		}
		
		private function initVideo():void
		{
			_isReady = true;
			// Включаем кнопки
			enableButtons();
			
			// Инициализируем камеру
			recordContainer = new StreamRecorder(netConnection, camera, microphone);
			recordContainer.x = width / 2 - recordContainer.width / 2;
			recordContainer.y = height / 2 - recordContainer.height / 2;			
			recordContainer.addEventListener(MessageEvent.MESSAGE_EVENT, onMessageEvent);
			cameraContainer.addChild(recordContainer);			
			//recordContainer.streamName = "cameraFeed";
			
			// Для проигрывания видео
			playContainer = new StreamPlayer(netConnection, camera.width, camera.height);
			playContainer.x = width / 2 - playContainer.width / 2;
			playContainer.y = height / 2 - playContainer.height / 2;
			playContainer.addEventListener(MessageEvent.MESSAGE_EVENT, onMessageEvent);
			playContainer.addEventListener(PublishEvent.PLAY_ERROR, onPlayError);
			streamContainer.addChild(playContainer);				
		}
		
		private function onPlayError(e:PublishEvent):void 
		{
			cameraContainer.visible = true;
			streamContainer.visible = false;
				
				// Показываем кнопки	
				with (controlPanel)
					{
						btnSave.visible = true;
						btnPlay.visible = true;
						btnRec.visible = true;
						
						// Расянуть окно сообщений
						messagePanel.x = 186;
						messagePanel.width = 213.5;
					}
					
			isPlayin = false;			
		}
		
		// Текстовые сообщения
		private function onMessageEvent(e:MessageEvent):void 
		{
			PutMsg(e.message);
		}
	}

}