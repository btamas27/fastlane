require_relative 'module'
require 'spaceship'
require 'open-uri'
require 'ffmpeg'
require_relative 'queue_worker'

require 'fastlane/helper/sh_helper'

module Deliver
  class DownloadPreviews
    def self.run(options, path)
      UI.message("Downloading all existing previews...")
      download(options, path)
      UI.success("Successfully downloaded all existing previews")
    rescue => ex
      UI.error(ex)
      UI.error("Couldn't download already existing previews from App Store Connect.")
    end

    def self.download(options, folder_path)
      app = options[:app]

      platform = Spaceship::ConnectAPI::Platform.map(options[:platform])
      if options[:use_live_version]
        version = app.get_live_app_store_version(platform: platform)
        UI.user_error!("Could not find a live version on App Store Connect. Try using '--use_live_version false'") if version.nil?
      else
        version = app.get_edit_app_store_version(platform: platform)
        UI.user_error!("Could not find an edit version on App Store Connect. Try using '--use_live_version true'") if version.nil?
      end

      localizations = version.get_app_store_version_localizations.select { |localization| localization.locale.eql?('en-US') }
      download_previews(localizations, folder_path)
    end

    def self.download_previews(localizations, folder_path)
      localizations.each do |localization|
        language = localization.locale
        preview_sets = localization.get_app_preview_sets
        preview_sets.each do |preview_set|
          preview_set.app_previews.each_with_index do |preview, index|
            file_name = [index, preview_set.preview_type, index].join("_")
            original_file_extension = File.extname(preview.file_name).strip.downcase[1..-1]
            file_name += "." + original_file_extension

            url = preview.video_url
            next if url.nil?

            # UI.message("Downloading existing preview '#{file_name}' for language '#{language}'")
            Helper.show_loading_indicator("Downloading existing preview '#{file_name}' for language '#{language}'")

            containing_folder = File.join(folder_path, language)
            begin
              FileUtils.mkdir_p(containing_folder)
            rescue
              # if it's already there
            end

            path = File.join(containing_folder, file_name)

            Fastlane::Actions.sh("ffmpeg -i #{url} -c copy #{path}", log: false)
            Helper.hide_loading_indicator
          end
        end
      end
    end
  end
end
