#!/bin/env ruby
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

require_relative 'lib/unspan_all_tables'

class String
  def to_date
    return if to_s.empty?
    Date.parse(self).to_s rescue nil
  end
end

class ListPage < Scraped::HTML
  decorator WikidataIdsDecorator::Links
  decorator UnspanAllTables

  field :officeholders do
    table.xpath('.//tr[td]').map { |tr| fragment(tr => PersonRow) }
  end

  private

  def table
    noko.xpath('//table[.//th[.="Term of office"]]')
  end
end

class PersonRow < Scraped::HTML
  field :name do
    tds[2].css('a').map(&:text).first
  end

  field :id do
    tds[2].css('a/@wikidata').map(&:text).first
  end

  field :start_date do
    tds[3].text.to_date
  end

  field :end_date do
    tds[4].text.to_date
  end

  field :source do
    url
  end

  private

  def tds
    noko.css('td')
  end
end

url = 'https://en.wikipedia.org/wiki/Chief_of_the_Cabinet_of_Ministers'
data = Scraped::Scraper.new(url => ListPage).scraper.officeholders.map(&:to_h)
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[name start_date], data)
