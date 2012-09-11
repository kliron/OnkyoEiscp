#!/usr/bin/env ruby

module OnkyoEiscp

  require 'socket'
  require 'observer'
  require 'readline'
  require 'timeout'
  require 'json'

@@help = %s{ Command reference:

    p0 => standby
    p1 => system on
    p? => Gets the system power status
    sb => Sets SurrBack Speaker
    sh => Sets FrontHigh / SurrBack + FrontHigh
    sw => Sets FrontWide / SurrBack + FrontWide
    shw => Sets Front High + Front Wide 
    up => Sets speaker switch wrap-around
    speaker? => Gets the speaker state
    m1 => Mute ON
    m0 => Mute OFF
    m? => Gets the audio muting state
    m => Sets audio muting wrap-around
    vu => Master volume level up
    vd => Master volume level down
    v => Followed by a hex literal in the range "00"-"64" (volume level in hexadecimal)
    v? => Get master volume level
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
    tu => Track up
    td => Track down
    u => Up
    d => Down
    s => Select current element. Pressing ENTER without any arguments translates also to 's'
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
    status? => State of the NET input     
    dlna 
    favorites 
    vtuner 
    lastfm 
    spotify
    goto => Custom command to quickly navigate to a destination 
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
  :vu => "MVLUP",
  :vd => "MVLDOWN",
  :v => ->(a) { "MVL" << a }, 
  :v? => "MVLQSTN",
  :sb => "SPLSB",
  :sh => "SPLFH",
  :sw => "SPLFW",
  :shw => "SPLHW",
  :up => "SPLUP",
  :speaker? => "SPLQSTN",
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
  :tu => "NTCTRUP",
  :td => "NTCTRDN",
  :u => "NTCUP",
  :d => "NTCDOWN",
  :s => "NTCSELECT",
  :n => ->(a) { "NLSL" << a },    
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
  :status? => "NSTQSTN",
  :dlna => "NSV000",
  :favorites => "NSV010",
  :vtuner => "NSV020",
  :lastfm => "NSV060",
  :spotify => "NSV0A1",
  :goto =>  { :folders => ["top", "6", "0", "1", "3"],
              :classic => ["top", "6", "0", "1", "3", "1"],
              :jazz => ["top", "6", "0", "1", "3", "0"],
              :rock => ["top", "6", "0", "1", "3", "9"],
              :collections => ["top", "6", "0", "1", "3", "2"],
              :soundtracks => ["top", "6", "0", "1", "3", "u", "0"],
              :unsorted => ["top", "6", "0", "1", "3", "u", "1"],
              :playlists => ["top", "6", "0", "1", "3", "7"],
              :radio => ["top", "0", "1"]
  }
  }

    class Watcher
    def initialize(c, f=:update)
      c.add_observer(self, f)
    end

    def update(state)
      entries = state[:content] || []
      idx = state[:cursor_pos]
      if state[:depth] == 22 or entries.empty?
        content = "... Playing ..."
      else
        content = entries.map do |s;c,i| 
        i = entries.index s
        c = i == idx ? "*" : " "
        "%c%i %s" % [c,i,s] 
        end.join("\n")
      end
      puts "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s" %
     [%[--------------% Folder Info %---------------],
      content,
      %[Source: #{state[:source] || "---"}], %[Title: #{state[:title] || "---"}],
      %[Artist: #{state[:artist] || "---"}], %[Album: #{state[:album] || "---"}],
      %[Track: #{state[:track] || "---/---"}, Time: #{state[:time]}],
      %[Volume: #{state[:volume]}, Mute: #{state[:mute]}, Speaker layout: #{state[:speaker_layout]}], 
      %[Status: #{state[:play]}, Repeat: #{state[:repeat]}, Shuffle: #{state[:shuffle]}],
      %[Current selection: #{state[:cursor_pos]}]]
      $stdout.flush
    end

    def jsonize(state)
      state.to_json
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
      @commandTimeout = 5       
    end


    def wait(interval=0.3)
      sleep interval
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
              data.split(/ISCP/).reject!(&:empty?).each do |p| 
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


    def send(c)
        size = c.length + 3
        packet = "ISCP\x00\x00\x00\x10\x00\x00\x00" << [size].pack("C") << 
        "\x01\x00\x00\x00!1" << c << "\r"
        @socket.write packet
        @lastPacket = packet
    end


    def do_command(*args)
      raise "Not connected" unless connected?
      raise "Wrong number of args" if args.length > 2
      
      if args.empty?
        key = "s"       # No args translates to "s". 
      elsif  args[0] =~ /^\d$/
        key, opt = "n", args[0]          # Single number translates to "n <number>"  
      else 
        key, opt = args[0], args[1]
      end       

      raise "#{key}: No such command" if (command = COMMANDS[key.to_sym]).nil?
      command = command.call opt if command.respond_to? :call

      if key == "goto"             
        raise "No such selecton" if (path = command[opt.to_sym]).nil?

        do_step = ->(step) do      
          # keeps redoing step until predicate returns true or commandTimeout is reached
          
          # State before the step
          d, c = @state[:depth], @state[:cursor_pos]   

          pred = case step
                 when /^\d$/  # list item selector
                   proc { @state[:depth] == d + 1 }
                 when /^u$/     # cursor up
                   proc do |;cp| 
                     cp = @state[:cursor_pos]
                     c == 0 ? cp >= 0 : cp == c - 1 
                   end
                 when /^d$/     # cursor down
                   proc do  |;cp| 
                     cp = @state[:cursor_pos]
                     c == 9 ? cp == 0 : cp == c + 1 
                   end
                 when /^top$/ 
                   proc { @state[:depth] == 0 }
                 end

          Timeout.timeout @commandTimeout do
            begin
              do_command step; wait 0.3  
            end until pred.call
          end
        end

        path.each { |step| do_step.call step }    
      else 
        send command; wait
      end
  end


    def update(m)
      type, params = m[0..2], m[3..m.length]

      op = case type
           when "NLT"
           # 1st byte is: the network source type
           # 2nd byte is: menu depth (how far you dug down)
           # 3rd,4th byte: selected item from list (index)
           # 5th, 6th: Index of item under cursor
           # 2nd to last byte: network icon for net GUI
           # Last byte: always 00      
             case params[0..1]
             when "00" then @state[:source] = "dlna"
             when "02" then  @state[:source] = "vtuner"
             when "F3" then  @state[:source] = "net"
             end
             @state[:depth] = params[2..3].to_i
             @state[:index] = params[4..5].to_i
           when "NTM" then @state[:time] = params; nil   # nil prevents observer's update calls 
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
             when "C" then @state[:cursor_pos] = idx.to_i
             when /A|U/
               @state[:content] = [] if idx == "0"
               @state[:content].push params[3..params.length]
             end
           else 
             nil
           end

      return if op.nil?
      changed
      notify_observers(@state)
    end


    def hello
      "artist track title ls v? m? speaker? status?".split.each { |c| do_command c } 
    end

  end



  def self.main
    
    client = OnkyoClient.new SERVER_IP, SERVER_PORT
    watcher = Watcher.new client, :update
    # 2 handlers user can switch at runtime. ^C to force client restart afterwards.
    printer = proc { |m| puts m unless m =~ /^NTM/ }
    updater = proc { |m| client.update m }
    handler = updater

    client.connect &handler
    client.hello

    stty_save = `stty -g`.chomp
    trap("INT") { puts "Restarting..."; client.disconnect; client.connect &handler } # ^C
    trap("QUIT") do  # ^\
      puts "Exiting!"
      client.disconnect
      system('stty', stty_save); exit! 1 
    end 

    # Main loop 
    loop do
      begin
        command = Readline.readline('>> ', true).chomp.strip
        case command
        when /^(:?\?|h|help)/
          # Print help
          puts @@help
        when /^\!/
          # Everything starting with "!" is a ruby command
          puts "#{eval command}"
        else 
          # Everything else is an onkyo command 
          client.do_command *command.split 
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
