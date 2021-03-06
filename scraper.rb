require 'scraperwiki'
require 'nokogiri'
require 'open-uri'

data = Nokogiri.parse(open('http://www.olgr.nsw.gov.au/liquor_applications/xml/application%20noticeboard%20data.xml').read, nil, 'utf-8')
info_url = 'http://www.ilga.nsw.gov.au/liquor/application-noticeboard'

data.search('APP').each do |a|
  # Some dates are so mangled that we have to skip the record
  begin
    if a.at('ST').inner_text.empty? || a.at('ST').inner_text.strip == "Please see attached"
      puts "Skipping application with bad address: #{a.at('AN').inner_text.strip}"
      next
    end

    address = "#{a.at('ST').inner_text.strip}, #{a.at('SU').inner_text.strip} #{a.at('PC').inner_text.strip}"
    # Some addresses don't have a street number
    address = "#{a.at('SN').inner_text.strip} #{address}" if a.at('SN')

    record = {
      'council_reference' => a.at('AN').inner_text.strip,
      'description'       => "#{a.at('LPN').inner_text.strip} - #{a.at('AT').inner_text.strip}",
      'date_received'     => Date.strptime(a.at('DP').inner_text.gsub('//', '/'), '%d/%m/%y').to_s,
      'address'           => address,
      'info_url'          => info_url,
      'comment_url'       => "mailto:liquorapplications@olgr.nsw.gov.au?subject=Application%20Number:%20" + a.at('AN').inner_text.strip,
      'on_notice_to'      => Date.strptime(a.at('SCD').inner_text.gsub('//', '/'), '%d/%m/%y').to_s,
      'date_scraped'      => Date.today.to_s
    }
  rescue ArgumentError => e
    if e.message == "invalid date"
      puts "Skipping record with invalid date #{a.at('AN').inner_text.strip}"
      next
    else
      raise e
    end
  end
  
  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    ScraperWiki.save_sqlite(['council_reference'], record)
  else
     puts "Skipping already saved record " + record['council_reference']
  end
end
