require 'nokogiri'
require 'optparse'

class ListErrors
  attr_accessor :messages, :count, :option, :type, :function, :output_option, :type_count
  attr_reader :directory

  def initialize
    @messages= []
    @type_counts = {}
    @count = 0
    @directory = sanitize_input
    @function = nil
    @type = nil
    @output_option = 0
  end

  def grab_all_failures(xml_file)
    xml_file.xpath('/*/testcase/failure')
  end

  def grab_failures_typed(xml_file, type)
    xml_file.xpath("//*[@type='#{type}']")
  end

  # sanitize directory input to remove / at the end if it is a directory, otherwise, just return the file name
  def sanitize_input
    location = ''
    ARGV.each { |arg| location = arg unless arg[-1] == '-' }
    if File.directory?(location)
      location = location[-1] == '/' ? location[0...-1] : location
    else
      location
    end
  end

  # create an array of files inside a directory, or a single element array containing only the input file
  # allows each to be called on output regardless of size
  def create_xml_array
    location = sanitize_input
    if File.directory?(location)
      Dir["#{location}/*.xml"]
    else
      Dir[location]
    end
  end

  # Parse the CLI option flags and store the correct operation as a Proc object
  # also sets the correct output format for each operation
  def set_function
    # return the help menu if no options are passed
    ARGV << '-h' unless ARGV.any?{|arg| arg[0] == '-'}
    OptionParser.new do |parser|
      parser.banner = 'Usage: example.rb [options] FILE/DIR'
      parser.on('-a', '--all', 'list all the errors') do
        self.function = Proc.new do |parsed_xml|
          grab_all_failures(parsed_xml).each do |failure|
            messages << failure
            self.count += 1
          end
        end
        self.output_option = 0
      end

      parser.on('--list-types', 'list the name of all unique types of errors') do
        self.function = Proc.new do |parsed_xml|
          grab_all_failures(parsed_xml).each do |failure|
            messages << failure['type']
          end
          unique_messages = messages.uniq
          # create a hash with each unique error type as a key and the count of errors of that type as the value
          self.type_count = unique_messages.each_with_object({}) do |message, memo|
            memo[message] = self.messages.count(message)
          end
        end
        self.output_option = 1
      end

      parser.on('-t', '--type TYPE', 'list all errors of type TYPE') do |type|
        self.function = Proc.new do |parsed_xml|
          grab_failures_typed(parsed_xml, type).each do |failure|
            messages << failure
            self.count += 1
          end
        end
        self.output_option = 2
      end

      parser.on('-h', '--help', 'Prints this help') do
        puts parser
        exit
      end
    end.parse!
  end

  def run_lister
    set_function
    # creates an array of files in DIR or array with single file. #each will work either way
    xml_input = create_xml_array
    # iterate of the array of rspec xml files, calling the previously set Proc on each
    xml_input.each_with_index do |xfile|
      parsed_xml = Nokogiri::XML(File.open(xfile))
      self.function.call(parsed_xml)
    end
    # determine the output format based on the current operation
    case output_option
    when 0 # list all errors
      puts messages
      puts "Errors found: #{count}"
    when 1 # list all error types
      # sort by number of errors in descending order
      type_count.sort_by{|k,v| -v}.each do |type, count|
        puts "#{type} - Count: #{count} "
      end
    when 2 # list all errors of specified type
      puts messages
      puts "Errors of type #{type} found: #{count}"
    end
  end
end

# Run the program
ListErrors.new.run_lister
