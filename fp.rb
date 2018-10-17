#my Twilio number: (614) 972-1846
require 'twilio-ruby'
require 'rickmorty'
require 'httparty'
require 'giphy'
require 'net/http' #emotion API library
require 'parseconfig'
require 'rest-client'
require 'themoviedb-api'

greetings = ["Hi", "Hello", "What up", "Yo"]
morning = ["Morning", "Good morning"]
afternoon = ["Afternoon", "Good afternoon"]
evening = ["Evening", "Good evening"]

#a secret code for signup #
code = "R2D2"

require 'sinatra'
require "sinatra/reloader" if development?


enable :sessions

configure :development do
  require 'dotenv'
  Dotenv.load
end


#------------------------------------------------------------------------------
#                         Basic endpoints on web
#------------------------------------------------------------------------------
get '/' do
  redirect to "/about"
end


get "/about" do
  session["visits"] ||= 0 # Set the session to 0 if it hasn't been set before
  session["visits"] = session["visits"] + 1  # adds one to the current value (increments)

  time = Time.now #returns the time today
  hour = time.hour
  time = time.strftime("%A %B %d, %Y %H:%M") # gives: Tuesday October 01, 2017 02:02

  ### BONUS - Customize greetings to AM / PM
  if hour > 0 && hour < 12
    greet = morning.sample
  elsif hour > 12 && hour < 17
    greet = afternoon.sample
  else
    greet = evening.sample
  end


  if session[:first_name].nil?
    greet + " new friend! My YesNo Bot is a minimal-interface to help you make a decision by
     drawing a poker card for you. <br/>You have visited " + session["visits"].to_s +
    " times as of " + time.to_s
  else
    greet + " " + session[:first_name] + "! My MeBot is a minimal-interface bot who tells you about the weather today and
    clothes recommendation. <br/>You have visited " + session["visits"].to_s +
    " times as of " + time.to_s
  end
end

#------------------------------------------------------------------------------
#            Use secrete code in URL to get into the sign up page
#------------------------------------------------------------------------------
get "/signup" do
  if params[:code] == code
    erb :signup
  else
    403
  end

end


#------------------------------------------------------------------------------
#                    Sending the first msg after sign up
#------------------------------------------------------------------------------
post "/signup" do
  # we'll add some code here
  # code to check parameters
  client = Twilio::REST::Client.new ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"]

  # Include a message here
   message = "Hi " + params[:first_name] + ", I am YesNo Bot! Are you curious about me? Say hi to me!"

  # this will send a message from any end point
  client.api.account.messages.create(
    from: ENV["TWILIO_FROM"],
    to: params[:number],
    body: message
  )
  # response if eveything is OK on the web page
  "You're signed up. You'll receive a text message in a few minutes from the bot. "

end


#Start Message
#
get "/sms/incoming" do
  session["counter"] ||= 1
  imageEmotion = 'empty'
  body = params[:Body] || "Hello!"
  sender = "Karan"
  media_content = params[:MediaContentType0] || "none"
  media_url = params[:MediaUrl0] || "none"

  if session["counter"] == 1
     message = "Hey! I'm NomNom. Looks like you're hungry. Send me a selfie for some food recommendations"
     media = "https://media.giphy.com/media/CDpAmfo9dbOyA/giphy.gif"
  else

if media_url == "none"
      message, media = determine_response body

    else
      message, media = call_face_api media_url
    end

  end


  #------------------------------------------------------------------------------
  #                           Twillio package
  #------------------------------------------------------------------------------
  # Build a twilio response object
  twiml = Twilio::TwiML::MessagingResponse.new do |r|
    r.message do |m|

      # add the text of the response
      m.body(message)
      puts message

      # add media if it is defined
      unless media.nil?
        m.media(media)
      end
    end
  end

  # increment the session counter
  session["counter"] += 1

  # send a response to twilio
  content_type 'text/xml'
  twiml.to_s

end


#------------------------------------------------------------------------------
#                            Testing endpoints
#------------------------------------------------------------------------------
get "/test/conversation" do
  #set 2 expected variables
  body = params[:Body]
  from = params[:From]

  #check if both variables are populated
  if body.nil?
     return "I don't see your Body.Check your URL for a correct Body input!"
  elsif from.nil?
     return "I don't see your From. Check your URL for a correct From input!"
  end
end

#------------------------------------------------------------------------------
#                            FACE API
#------------------------------------------------------------------------------
# Note: You must use the same region in your REST call as you used to obtain your subscription keys.
#   For example, if you obtained your subscription keys from westcentralus, replace "westus" in the
#   URL below with "westcentralus".

# You must use the same location in your REST call as you used to get your
# subscription keys. For example, if you got your subscription keys from  westus,
# replace "westcentralus" in the URL below with "westus".

def call_face_api media_url

  Tmdb::Api.key("aa73605e3dfbc5266697038b580c3678")

  uri = URI('https://westcentralus.api.cognitive.microsoft.com/face/v1.0/detect')
  uri.query = URI.encode_www_form({
      # Request parameters
      'returnFaceId' => 'true',
      'returnFaceLandmarks' => 'false',
      'returnFaceAttributes' => 'age,gender,headPose,smile,facialHair,glasses,' +
          'emotion,hair,makeup,occlusion,accessories,blur,exposure,noise'
  })

  request = Net::HTTP::Post.new(uri.request_uri)

  # Request headers
  # Replace <Subscription Key> with your valid subscription key.
  request['Ocp-Apim-Subscription-Key'] = '74e4615ad75b40179c0cca590c66615c'
  request['Content-Type'] = 'application/json'

  imageUri = media_url
  request.body = "{\"url\": \"" + imageUri + "\"}"

  response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(request)
  end

  puts "RESPONSE = "
  puts response.body

  json = JSON.parse( response.body )

  emotions = json.first["faceAttributes"]["emotion"]

  searchEmotion = emotions.max_by{|k,v| v}[0]

  if searchEmotion == "happiness"
    response = Tmdb::Genre.movies(35)
    puts 'selecting a comedy'

  elsif seachEmotion == "sadness"
    response = Tmdb::Genre.movies(18)
    puts 'selecting a drama'

  end

  number = rand(19)

  title = response['results'][number]["original_title"]
  poster = response['results'][number]["poster_path"]

  media = 'https://image.tmdb.org/t/p/w1280' + poster
  message = 'One option I have for you is ' + title + '. If you want another option, type [yes].'

  return message, media


end

#------------------------------------------------------------------------------
#                           Method of all responses
#------------------------------------------------------------------------------
def determine_response body
  #normalize and clean the string
  body = body.downcase.strip

  # value = call_face_api
  # puts "Highest Emotion is #{value}"


  if body.include?( "comedy") || body.include?("happy")
    response = "You could use some junk food!"

  elsif body.include?( "drama" )|| body.include?( "sad")
    response = "You could use some ice cream!"

  elsif body == 'yes'

  end

    return 
end


error 403 do
  "Access Forbidden"
end
