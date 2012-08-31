#!/usr/bin/env ruby

module OnkyoEiscp

  require 'socket'
  require 'observer'

@@help = %s{

  Command reference:

    p0 => standby
    p1 => system on
    p? => Gets the system power status
    sb => Sets SurrBack Speaker
    sh => Sets FrontHigh / SurrBack + FrontHigh
    sw => Sets FrontWide / SurrBack + FrontWide
    shw => Sets Front High + Front Wide 
    up => Sets speaker switch wrap-around
    s? => Gets the speaker state
    m1 => Mute ON
    m0 => Mute OFF
    m? => Gets the audio muting state
    m => Sets audio muting wrap-around
    au => Master volume level up
    ad => Master volume level down
    a => Followed by a hex literal in the range "00"-"64" (volume level in hexadecimal)
    a? => Get master volume level
    net => NET 
    vcr => VCR/DVR
    cbl => CBL/SAT
    game => GAME/TV
    aux => AUX
    pc => PC
    bd => BD/DVD
    fm => FM
    am => AM
    tuner => TUNER
    usb => USB
    iu => Input Selector position up
    id => Input Selector position down
    i? => Gets the selector position
    f => Followed by 5 digit integer (no spaces). Sets radio frequency.
    f? => Get the tuning frequency
    fdt => Starts/restarts Direct Tunning Mode
    play      
    stop 
    pause 
    repeat 
    random 
    display 
    right 
    left 
    tup => Track up
    tdn => Track down
    u => Up
    d => Down
    s => Select 
    n => Followed by a number 0-9 (separated by space). Select line number. 
    r => Return
    cu => Channel up (iRadio)
    cd => Channel down (iRadio)
    ls => List
    menu 
    top => Top menu for the NET input selector
    artist 
    album 
    title 
    track 
    n? => State of the NET input     
    dlna 
    favorites 
    vtuner 
    lastfm 
    spotify
}


  SERVER_IP = "192.168.1.100"
  SERVER_PORT = "60128"

  COMMANDS = {
  :p0 => "PWR00",
  :p1 => "PWR01",
  :p? => "PWRQSTN",
  :m0 => "AMT00",      
  :m1 => "AMT01",
  :m? => "AMTQSTN",
  :m => "AMTTG",
  :au => "MVLUP",
  :ad => "MVLDOWN",
  :a => ->(a) { "MVL" << a }, 
  :a? => "MVLQSTN",
  :sb => "SPLSB",
  :sh => "SPLFH",
  :sw => "SPLFW",
  :shw => "SPLHW",
  :up => "SPLUP",
  :s? => "SPLQSTN",
  :net => "SLI2B",
  :vcr => "SLI00",
  :cbl => "SLI01",
  :game => "SLI02",
  :aux => "SLI03",
  :pc => "SLI05",
  :bd => "SLI10",
  :fm => "SLI24",
  :am => "SLI25",
  :tuner => "SLI26",
  :usb => "SLI2C",
  :iu => "SLIUP",
  :id => "SLIDOWN",
  :i? => "SLIQSTN",
  :f => ->(a) { "TUN" << a },
  :f? => "TUNQSTN",
  :fdt => "TUNDIRECT",
  :play => "NTCPLAY",
  :stop => "NTCSTOP",
  :pause => "NTCPAUSE",
  :repeat => "NTCREPEAT",
  :random => "NTCRANDOM",
  :display => "NTCDISPLAY",
  :right => "NTCRIGHT",
  :left => "NTCLEFT",
  :tup => "NTCTRUP",
  :tdn => "NTCTRDN",
  :u => "NTCUP",
  :d => "NTCDOWN",
  :s => "NTCSELECT",
  :n => ->(a) { "NLSL" << a },    # Select line a. For convenience, if the user gives 
                                  # just a number between 0-9 it gets translated as "n <num>"  
  :r => "NTCRETURN",
  :cu => "NTCCHUP",
  :cd => "NTCCHDN",
  :ls => "NTCLIST",
  :menu => "NTCMENU",
  :top => "NTCTOP",
  :artist => "NATQSTN",
  :album => "NALQSTN",
  :title => "NTIQSTN",
  :track => "NTRQSTN",
  :n? => "NLSQSTN",
  :dlna => "NSV000",
  :favorites => "NSV010",
  :vtuner => "NSV020",
  :lastfm => "NSV060",
  :spotify => "NSV0A1"
  }


  class Watcher
    def initialize(c)
      c.add_observer(self)
    end

    def update(state)
      puts "--------------% Folder Info %---------------"
      state[:folder_entries].each { |e| puts "#{e[0]} #{e[1]}" } unless state[:folder_entries].nil?
      puts "Artist: #{state[:artist]}"
      puts "Album: #{state[:album]}"
      puts "Track: #{state[:track]}"
      puts "Volume: #{state[:volume]}, Mute: #{state[:mute]}, Speaker layout: #{state[:speaker_layout]}"
      puts "Cursor at: #{state[:cursor_pos]}"
      puts "Play: #{state[:play]}, Repeat: #{state[:repeat]}, Shuffle: #{state[:shuffle]}"
      puts "Time: #{state[:time]}"
    end
  end



  class OnkyoClient

    include Observable

    attr_reader :ip, :port, :socket, :listener, :state, :connected, :lastPacket

    def initialize(ip, port)
      @connected = false
      @state = Hash.new
      @ip = ip
      @port = port
      @lastPacket = nil
    end


    def connect(&handler)
      begin 
        @socket = TCPSocket.open ip, port
      rescue Exception => e
        puts e 
        raise
      end
     
      @listener = Thread.fork do
        loop do 
          begin
            data = ""
            while packet = @socket.recv(1024)
              data << packet
              next unless packet =~ /\r\n$/
              data.split(/ISCP/).each do |p| 
                msg = p[14..-4]  # first 13 bytes are the header, last 3 the EOL sequence
                handler.call msg unless msg.nil?   
              end
              data = ""
            end
          rescue Exception => e 
            puts e 
            raise
          end
        end
      end
      @connected = true
    end


    def disconnect
      @listener.kill
      @socket.close
    end

    
    def connected? 
      @connected
    end


    def send(c, *arg)
      raise "Not connected" unless connected?
      # plain numbers get translated as the "n" command followed by the given number
      c, arg = "n", c if c =~ /[0-9]/      
      command = COMMANDS[c.to_sym]
      raise "No such command" if command.nil?
      command = command.call arg[0] if command.respond_to? :call
      size = command.length + 3
      packet = "ISCP\x00\x00\x00\x10\x00\x00\x00" << [size].pack("C") << 
               "\x01\x00\x00\x00!1" << command << "\r"

      @socket.write packet
      @lastPacket = packet
    end


    def update(m)
      type, params = m[0..2], m[3..m.length]

      op = case type
           when "NTM" then @state[:time] = params; nil   # prevents observer's update calls 
           when "NAT" then @state[:artist] = params 
           when "NAL" then @state[:album] = params 
           when "NTI" then @state[:title] = params
           when "NTR" then @state[:track] = params
           when "MVL" then @state[:volume] = params
           when "AMT" then @state[:mute] = params == "00" ? "off" : "on"
           when "SPL" then @state[:speaker_layout] = params;
           when "NST"
             case params[0]
             when "P" then @state[:play] = "play"
             when "S" then @state[:play] = "stop"
             when "p" then @state[:play] = "pause"
             when "F" then @state[:play] = "FF"
             when "R" then @state[:play] = "FR"
             end
             case params[1]
             when "-" then @state[:repeat] = "off"
             when "R" then @state[:repeat] = "all"
             when "F" then @state[:repeat] = "folder"
             when "1" then @state[:repeat] = "1"
             end
             case params[2]
             when "-" then @state[:shuffle] = "off"
             when "S" then @state[:shuffle] = "all"
             when "A" then @state[:shuffle] = "album"
             when "F" then @status[:shuffle] = "folder"
             end
           when "NLS"
             idx = params[1]
             case params[0]
             when "C" then @state[:cursor_pos] = idx
             when /A|U/
               @state[:folder_entries] = [] if idx == "0"
               @state[:folder_entries].push [idx, params[3..params.length]]
             end
           else 
             nil
           end

      return if op.nil?
      changed
      notify_observers(@state)
    end


    def hello
      # Reducing the sleep time often causes onkyo to become unresponsive
      puts "Getting onkyo state..."
      sleep 0.2
      send "artist"; sleep 0.2
      send "track"; sleep 0.2
      send "title"; sleep 0.2
      send "ls"; sleep 0.2
      send "a?"; sleep 0.2
      send "m?"; sleep 0.2
      send "s?"; sleep 0.2
      send "n?"; sleep 0.2  
    end

  end



  def self.main
    
    client = OnkyoClient.new SERVER_IP, SERVER_PORT
    watcher = Watcher.new client
    # 2 handlers user can switch at runtime. ^C to force client restart afterwards.
    printer = proc { |m| puts m unless m =~ /^NTM/ }
    updater = proc { |m| client.update m }
    handler = updater

    client.connect &handler
    client.hello

    trap("INT") { puts "Restarting..."; client.disconnect; client.connect &handler } # ^C
    trap("QUIT") { puts "Ouch!"; client.disconnect; exit! 1 } # ^\

    # Main loop 
    loop do
      begin
        command = gets.chomp.strip
        case command
        when /^(:?\?|h|help)/
          # Print help
          puts @@help
        when /^\!/
          # Everything starting with "!" is a ruby command
          puts "#{eval command}"
        else 
          # Everything else is an onkyo command 
          client.send *(command.split)
        end
      rescue Exception => e
        puts e 
        retry
      end
    end
  end

end


if __FILE__ == $0
  OnkyoEiscp::main
end
