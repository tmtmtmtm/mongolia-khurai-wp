#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri/cached'
require 'field_serializer'
require 'pry'

class Table
  def initialize(node)
    @table = node
  end

  def rows
    constituency = nil
    table.xpath('.//tr[td]').map do |tr|
      tds = tr.xpath('./td')
      constituency = tds.shift.text.strip.gsub("\n",' — ') if tds.first[:rowspan]
      tds.shift if tds.count == 5 # 2016 table has an extra column
      Row.new(tds).to_h.merge(constituency: constituency)
    end
  end

  private

  attr_reader :table
end

class Row
  include FieldSerializer

  def initialize(tds)
    @tds = tds
  end

  field :name do
    tds[0].xpath('.//a').text.strip
  end

  field :name_mn do
    tds[1].text.strip
  end

  field :party do
    tds[3].text.strip
  end

  field :wikiname do
    tds[0].xpath('.//a[not(@class="new")]/@title').text.strip
  end

  private

  attr_reader :tds
end

class Khurai
  def initialize(url)
    @url = url
    @term = term
  end

  def members
    Table.new(table).rows
  end

  private

  attr_reader :url, :term

  def page
    Nokogiri::HTML(open(url).read)
  end

  def table
    page.xpath('.//h2/span[text()[contains(.,"Constituency")]]/following::table[1]')
  end
end

class Term
  def initialize(term, url)
    @members = Khurai.new(url).members
    @term = term
  end

  def members
    @members.map do |member|
      member.merge(term: term)
    end
  end

  private

  attr_reader :term
end

def save(term)
  term.members.each do |mem|
    ScraperWiki.save_sqlite([:name, :term], mem)
  end
end

base_url = 'https://en.wikipedia.org/wiki/'
terms = [
  { year: '2016', url: 'List_of_MPs_elected_in_the_Mongolian_legislative_election,_2016' },
  { year: '2012', url: 'List_of_MPs_elected_in_the_Mongolian_legislative_election,_2012' },
  { year: '2008', url: 'List_of_MPs_elected_in_the_Mongolian_legislative_election,_2008' },
]

terms.each do |term|
  save(Term.new(term[:year], base_url + term[:url]))
end
