# encoding: utf-8

module Sinatra
  module Bloodhound
    module Uploaders

      def upload_file(user_id:, created_by:)
        @error = nil
        @record_count = 0
        if params[:file] && params[:file][:tempfile]
          tempfile = params[:file][:tempfile]
          filename = params[:file][:filename]
          mime_encoding = detect_mime_encoding(tempfile.path)
          if ["text/csv", "text/plain"].include?(mime_encoding[0]) && tempfile.size <= 5_000_000
            begin
              items = []
              CSV.foreach(tempfile, headers: true, header_converters: :symbol, encoding: "#{mime_encoding[1]}:utf-8") do |row|
                action = row[:action].gsub(/\s+/, "") rescue nil
                next if action.blank? && row[:not_me].blank?
                if UserOccurrence.accepted_actions.include?(action) && row.headers.include?(:gbifid)
                  items << UserOccurrence.new({
                    occurrence_id: row[:gbifid],
                    user_id: user_id,
                    created_by: created_by,
                    action: action
                  })
                  @record_count += 1
                elsif (row[:not_me].downcase == "true" || row[:not_me] == 1) && row.headers.include?(:gbifid)
                  items << UserOccurrence.new({
                    occurrence_id: row[:gbifid],
                    user_id: user_id,
                    created_by: created_by,
                    action: nil,
                    visible: 0
                  })
                  @record_count += 1
                end
              end
              UserOccurrence.import items, batch_size: 250, validate: false, on_duplicate_key_ignore: true
              tempfile.unlink
            rescue
              tempfile.unlink
              @error = "There was an error in your file. Did it at least contain the headers, action and gbifID and were columns separated by commas?"
            end
          else
            tempfile.unlink
            @error = "Only files of type text/csv or text/plain less than 5MB are accepted."
          end
        else
          @error = "No file was uploaded."
        end
      end

      def upload_image
        new_name = nil
        if params[:file] && params[:file][:tempfile]
          tempfile = params[:file][:tempfile]
          filename = params[:file][:filename]
          mime_encoding = detect_mime_encoding(tempfile.path)
          if ["image/jpeg", "image/png"].include?(mime_encoding[0]) && tempfile.size <= 5_000_000
            extension = File.extname(tempfile.path)
            filename = File.basename(tempfile.path, extension)
            new_name = Digest::MD5.hexdigest(filename) + extension
            FileUtils.chmod 0755, tempfile
            FileUtils.mv(tempfile, File.join(root, "public", "images", "users", new_name))
          else
            tempfile.unlink
          end
        end
        new_name
      end

      def csv_stream_headers(file_name = "download")
        content_type "application/csv", charset: 'utf-8'
        attachment !params[:id].nil? ? "#{params[:id]}.csv" : "#{file_name}.csv"
        cache_control :no_cache
        headers.delete("Content-Length")
      end

      # from https://stackoverflow.com/questions/24897465/determining-encoding-for-a-file-in-ruby
      def detect_mime_encoding(file_path)
        mt = FileMagic.new(:mime_type)
        me = FileMagic.new(:mime_encoding)
        [mt.file(file_path), me.file(file_path)]
      end

    end
  end
end