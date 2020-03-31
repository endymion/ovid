require 'rubygems'
require 'bundler'

Bundler.require

require "./flovid"

if Flovid.development?
  require 'dotenv'
  Dotenv.load
else
  Bugsnag.configure do |config|
    config.api_key = ENV["BUGSNAG_API_KEY"]
  end

  use Bugsnag::Rack
end

run lambda { |env|
  [
    200,
    {'Content-Type'=>'text/html'},
    StringIO.new(payload(env["QUERY_STRING"]))
    ]
}

def pretty_datetime(time)
  format = "%A %B %e, %Y at %H:%M:%S %Z".freeze

  if time.respond_to? :strftime
    time.strftime(format)
  else
    Time.parse(time).strftime(format)
  end
end

def payload(query_string)
  report = Flovid.covid_tracking_report(query_string)

  last_edit = pretty_datetime report[:last_edited_at]
  last_fetched = pretty_datetime report[:last_fetched_at]
  expires_at = pretty_datetime report[:expires_at]

  <<~HTML
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="UTF-8">
    <title>Florida COVID-19 Report</title>
    <style type="text/css">
      body {
        font-family: Tahoma, sans-serif;
      }
      th, td {
        padding: 0.3rem 1rem;
      }
      th {
        width: 50%;
      }

      td {
        width: 50%;
      }

      td:first-child, th:first-child {
        text-align: right;
      }

      td:last-child, th:last-child {
        text-align: left;
      }

      tr:nth-child(even) { background: #CCC }
      tr:nth-child(odd) { background: #FFF }
    </style>
  </head>
  <body>
    <h1>Florida COVID-19 Report</h1>
    <p>
      This report is generated from the Florida Department of Health's
      <a href="#{Flovid::TESTING_GALLERY_URL}">
      <em>COVID -19 Testing Data for the State of Florida</em></a> feature layer hosted
      on the <a href="https://fdoh.maps.arcgis.com/home/index.html">FDOH's Esri ARCGIS</a>
      account.
    </p>

    #{report_table(report[:data])}

    <p><code>*</code> denotes metrics tracked by the COVID Tracking Project</p>

    <footer>
      Data last generated by FDOH at <strong>#{last_edit}</strong>.<br />
      Last fetched from FDOH API at <strong>#{last_fetched}</strong>.<br />
      This data will remain cached until <strong>#{expires_at}</strong> so you don't need to
      refresh this page until then to get new data.
    </footer>
  </body>
  </html>
  HTML
end

def report_table(data)
  rows = data.map do |_key, metric|
    <<~HTML
      <tr>
        <td title="#{metric[:source]}">#{metric[:name]}#{"*" if metric[:highlight]}</td>
        <td>#{metric[:value]}</td>
      </tr>
    HTML
  end.join("\n")

  output = <<~HTML
    <table>
      <tr>
        <th>Metric</th>
        <th>Value</th>
      </tr>
      #{rows}
    </table>
  HTML
end
