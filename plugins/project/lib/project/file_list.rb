module Redcar
  class Project
    class FileList
      attr_reader :path
    
      def initialize(path)
        @path = File.expand_path(path)
        @files = {}
      end
      
      def all_files
        @files.keys
      end
      
      def contains?(file)
        @files[file]
      end
      
      def update
        @files = find(path)
      end
      
      def changed_since(time)
        result = {}
        @files.each do |file, mtime|
          if mtime.to_i >= time.to_i - 1
            result[file] = mtime
          end
        end
        result
      end
      
      private
      
      def find(*paths)
        files = {}
        paths.collect!{|d| d.dup}
        while file = paths.shift
          stat = File.lstat(file)
          unless file =~ /\.git|\.yardoc|\.svn/
            unless stat.directory?
              files[file.dup] = stat.mtime
            end
            next unless File.exist? file
            begin
              if stat.directory? then
                d = Dir.open(file)
                begin
                  for f in d
                    next if f == "." or f == ".."
                    if File::ALT_SEPARATOR and file =~ /^(?:[\/\\]|[A-Za-z]:[\/\\]?)$/ then
                      f = file + f
                    elsif file == "/" then
                      f = "/" + f
                    else
                      f = File.join(file, f)
                    end
                    paths.unshift f.untaint
                  end
                ensure
                  d.close
                end
              end
            rescue Errno::ENOENT, Errno::EACCES
            end
          end
        end
        files
      end
    end
  end
end