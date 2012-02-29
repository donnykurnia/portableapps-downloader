#!/usr/bin/env ruby

###############################################################################
#
# PortableApps Downloader 0.0.4
#
# Copyright (C) 2011 Donny Kurnia <donnykurnia@gmail.com>
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses>.
#
###############################################################################

#load required modules
require 'open-uri'
require 'nokogiri'
require 'yaml'

#constants
BASE_URL = 'http://portableapps.com'
CACHE_FILE = 'cache.yml'
DL_LINKS = []

#functions
def get_news_pages(page, news_pages, page_cache)
  cache_hit = false
  p "Reading #{page} ..."
  doc = Nokogiri::HTML(open(page))
  doc.search('//td[@class = "views-field views-field-title"]/a[@href]').each do |m|
    news_page = BASE_URL + m[:href]
    cache_hit = page_cache.include? news_page
    if cache_hit
      break
    else
      unless news_page.nil? || news_page.include?("beta")
        news_pages << news_page
      end
    end
  end
  next_page_link = doc.search('//a[@title = "Go to next page"]')[0]
  if next_page_link && ! cache_hit
    news_pages = get_news_pages(BASE_URL + next_page_link[:href], news_pages, page_cache)
  end
  news_pages
end

def url_unescape(string)
  string.tr('+', ' ').gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
    [$1.delete('%')].pack('H*')
  end
end

def get_apps(news_pages, existing_files)
  news_pages.each_with_index do |page, i|
    #get app page
    p "Processing #{page} #{i+1}/#{news_pages.count}"
    doc = Nokogiri::HTML(open(page))
    app_page_link = doc.search('//div[@id = "maincontent"]/div[@class = "node"]/div[@class = "content"]/p/a[@href]')[0][:href]

    #try to find app link
    app_page_doc = Nokogiri::HTML(open(app_page_link))
    app_link_element = app_page_doc.search('//a[@class = "download-link"]')
    if app_link_element.length > 0
      app_link = app_link_element[0][:href]
    else
      app_page_doc.search('//div[@id = "maincontent"]/div[@class = "node"]/div[@class = "content"]/table//a[@href]').each do |link|
        if link[:href].include? "English.paf"
          app_link = link[:href]
          break
        end
      end
    end

    if app_link.nil?
      p "Cannot find download link in #{app_page_link}"
    else
      if app_link.include? "bouncer"
        app_link = url_unescape( app_link.gsub( /^.*\/bouncer\?t\=/, '' ) )
      end

      unless existing_files.any? { |file| app_link.include? file } or DL_LINKS.include?(app_link)
        DL_LINKS << app_link
        p "Downloading #{app_link}"
        filename = app_link.split("/").last.split("?").first
        %x(curl -L -C - "#{app_link}" -o #{filename}.tmp --limit-rate 30k )
        %x(mv #{filename}.tmp #{filename} )
      end
    end
  end
end

#load video page cache
page_cache = YAML::load(File.open(CACHE_FILE, File::RDONLY|File::CREAT)) || []

#get existing episodes
existing_files = Dir.glob('*.exe')

#get videos pages url from Railscasts pages
news_pages = get_news_pages("#{BASE_URL}/news", [], page_cache)

#write back the cache
page_cache = news_pages | page_cache
File.open(CACHE_FILE, 'w') do |f|
  f.write(page_cache.to_yaml)
end

get_apps(page_cache, existing_files)

p 'Finished downloading portable apps updates'
