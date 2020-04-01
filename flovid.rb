require "date"
require "time"
require "net/http"
require "json"

class Flovid
  STATE = "Florida"
  DEPARTMENT = "Florida Department of Health"
  ACRONYM = "FDOH"

  CACHE_KEY = "covid_#{STATE.downcase}"
  CACHE_EXPIRATION_IN_MINUTES = 15


  def self.testing_gallery_url
    "https://fdoh.maps.arcgis.com/home/item.html?id=d9de96980b574ccd933da024a0926f37"
  end

  def self.testing_feature_url
    "https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_Testing/FeatureServer/0?f=pjson"
  end

  def self.testing_data_url
    "https://services1.arcgis.com/CY1LXxl9zlJeBuRZ/arcgis/rest/services/Florida_Testing/FeatureServer/0/query?where=1%3D1&objectIds=&time=&geometry=&geometryType=esriGeometryEnvelope&inSR=&spatialRel=esriSpatialRelIntersects&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=*&returnGeometry=false&returnCentroid=false&featureEncoding=esriDefault&multipatchOption=none&maxAllowableOffset=&geometryPrecision=&outSR=&datumTransformation=&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&orderByFields=&groupByFieldsForStatistics=&outStatistics=&having=&resultOffset=&resultRecordCount=&returnZ=false&returnM=false&returnExceededLimitFeatures=true&quantizationParameters=&sqlFormat=none&f=pjson"
  end

  def self.dashboard_url
    "https://experience.arcgis.com/experience/96dd742462124fa0b38ddedb9b25e429"
  end

  def self.covid_tracking_report(query_string)
    stored_response = check_cache(CACHE_KEY)

    if stored_response && !query_string.include?("reload")
      puts "Using stored_response..."
      stored_response
    else
      puts "Generating new report ..."
      get_data
    end
  end

  def self.last_edit
    uri = URI(testing_feature_url)
    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)
    Time.strptime(parsed_response["editingInfo"]["lastEditDate"].to_s, "%Q")
  end

  def self.get_data
    uri = URI(testing_data_url)
    response = Net::HTTP.get(uri)
    parsed_response = JSON.parse(response)

    report = generate_report(parsed_response["features"])

    # set expiration time to 15 minutes from now
    last_fetch = Time.now
    expiration_time = last_fetch + (CACHE_EXPIRATION_IN_MINUTES * 60)

    cache = {
      last_edited_at: last_edit.iso8601,
      last_fetched_at: last_fetch.iso8601,
      expires_at: expiration_time.iso8601,
      data: report
    }

    write_cache(CACHE_KEY, cache)
    set_expiration(CACHE_KEY, expiration_time)
    check_cache(CACHE_KEY)
  end

  def self.generate_report(testing_data)
    # Example testing_data:
    #
    # {"OBJECTID_12_13"=>1,
    #  "OBJECTID"=>1,
    #  "DEPCODE"=>21,
    #  "COUNTY"=>"041",
    #  "COUNTYNAME"=>"GILCHRIST",
    #  "DATESTAMP"=>"2000-05-16T00:00:00.000Z",
    #  "ShapeSTAre"=>9908353355.45099,
    #  "ShapeSTLen"=>487300.011359113,
    #  "OBJECTID_1"=>21,
    #  "County_1"=>"Gilchrist",
    #  "State"=>"FL",
    #  "OBJECTID_12"=>"1",
    #  "DEPCODE_1"=>21,
    #  "COUNTYN"=>"41",
    #  "PUIsTotal"=>32,
    #  "Age_0_4"=>3,
    #  "Age_5_14"=>0,
    #  "Age_15_24"=>4,
    #  "Age_25_34"=>3,
    #  "Age_35_44"=>7,
    #  "Age_45_54"=>3,
    #  "Age_55_64"=>3,
    #  "Age_65_74"=>3,
    #  "Age_75_84"=>4,
    #  "Age_85plus"=>2,
    #  "Age_Unkn"=>0,
    #  "C_Age_0_4"=>0,
    #  "C_Age_5_14"=>0,
    #  "C_Age_15_24"=>0,
    #  "C_Age_25_34"=>0,
    #  "C_Age_35_44"=>0,
    #  "C_Age_45_54"=>0,
    #  "C_Age_55_64"=>0,
    #  "C_Age_65_74"=>0,
    #  "C_Age_75_84"=>0,
    #  "C_Age_85plus"=>0,
    #  "PUIAgeAvrg"=>"0",
    #  "PUIAgeRange"=>"0 to 89",
    #  "C_AgeAvrg"=>"46",
    #  "C_AgeRange"=>"NA",
    #  "C_AllResTypes"=>0,
    #  "C_NonResDeaths"=>0,
    #  "PUIFemale"=>17,
    #  "PUIMale"=>15,
    #  "PUISexUnkn"=>0,
    #  "PUIFLRes"=>32,
    #  "PUINotFLRes"=>0,
    #  "PUIFLResOut"=>0,
    #  "PUITravelNo"=>5,
    #  "PUITravelUnkn"=>27,
    #  "PUITravelYes"=>0,
    #  "C_ED_NO"=>0,
    #  "C_ED_NoData"=>0,
    #  "C_ED_Yes"=>0,
    #  "C_Hosp_No"=>0,
    #  "C_Hosp_Nodata"=>0,
    #  "C_Hosp_Yes"=>0,
    #  "FLResDeaths"=>0,
    #  "PUILab_Yes"=>32,
    #  "TPositive"=>0,
    #  "TNegative"=>32,
    #  "TInconc"=>0,
    #  "TPending"=>0,
    #  "PUIContNo"=>1,
    #  "PUIContUnkn"=>2,
    #  "PUIContYes"=>0,
    #  "CasesAll"=>0,
    #  "C_Men"=>0,
    #  "C_Women"=>0,
    #  "C_FLRes"=>0,
    #  "C_NotFLRes"=>0,
    #  "C_FLResOut"=>0,
    #  "T_NegRes"=>32,
    #  "T_NegNotFLRes"=>0,
    #  "T_total"=>32,
    #  "T_negative"=>32,
    #  "T_positive"=>0,
    #  "Deaths"=>0,
    #  "EverMon"=>0,
    #  "MonNow"=>0,
    #  "Shape__Area"=>0.0858306455302227,
    #  "Shape__Length"=>1.42926667474908}
    #

    testing_totals = relevant_keys.each_with_object({}) do |(key, metric), store|
      store[key] = {
        value: 0,
        name: metric[:name],
        highlight: metric[:highlight],
        source: metric[:source]
      }
    end

    testing_data.each_with_object(testing_totals) do |test, store|
      a = test["attributes"]

      relevant_keys.each do |key, value|
        store[key][:value] += a[value[:source]] || 0
      end
    end
  end

  def self.relevant_keys
    {
      age_0_to_4: {
        name: "PUIs - Age - 0 to 4",
        highlight: false,
        source: "Age_0_4"
      },
      age_5_to_14: {
        name: "PUIs - Age - 5 to 14",
        highlight: false,
        source: "Age_15_24"
      },
      age_15_to_24: {
        name: "PUIs - Age - 15 to 24",
        highlight: false,
        source: "Age_15_24"
      },
      age_25_to_34: {
        name: "PUIs - Age - 25 to 34",
        highlight: false,
        source: "Age_25_34"
      },
      age_35_to_44: {
        name: "PUIs - Age - 35 to 44",
        highlight: false,
        source: "Age_35_44"
      },
      age_45_to_54: {
        name: "PUIs - Age - 45 to 54",
        highlight: false,
        source: "Age_45_54"
      },
      age_55_to_64: {
        name: "PUIs - Age - 55 to 64",
        highlight: false,
        source: "Age_55_64"
      },
      age_65_to_74: {
        name: "PUIs - Age - 65 to 74",
        highlight: false,
        source: "Age_65_74"
      },
      age_75_to_84: {
        name: "PUIs - Age - 75 to 84",
        highlight: false,
        source: "Age_75_84"
      },
      age_85_and_over: {
        name: "PUIs - Age - 85 and over",
        highlight: false,
        source: "Age_85plus"
      },
      age_unknown: {
        name: "PUIs - Age - Unknown",
        highlight: false,
        source: "Age_Unkn"
      },
      PUIs_residents: {
        name: "PUIs - Residents",
        highlight: false,
        source: "PUIFLRes"
      },
      PUIs_non_residents: {
        name: "PUIs - Non-residents",
        highlight: false,
        source: "PUINotFLRes"
      },
      PUIs_residents_out: {
        name: "PUIs - Residents Out of State",
        highlight: false,
        source: "PUIFLResOut"
      },
      PUIs_female: {
        name: "PUIs - Female",
        highlight: false,
        source: "PUIFemale"
      },
      PUIs_male: {
        name: "PUIs - Male",
        highlight: false,
        source: "PUIMale"
      },
      PUIs_sex_unknown: {
        name: "PUIs - Sex Unknown",
        highlight: false,
        source: "PUISexUnkn"
      },
      positive_no_emergency_admission: {
        name: "Positive Tests - No ER Admission",
        highlight: false,
        source: "C_ED_NO"
      },
      positive_emergency_admission: {
        name: "Positive Tests - ER Admission",
        highlight: false,
        source: "C_ED_Yes"
      },
      positive_unknown_emergency_admission: {
        name: "Positive Tests - Unknown ER Admission",
        highlight: false,
        source: "C_ED_NoData"
      },
      positives_total_quality: {
        name: "Positive Tests - Total (Quality Control)",
        highlight: false,
        source: "TPositive"
      },
      negatives_total_quality: {
        name: "Negative Tests - Total (Quality Control)",
        highlight: false,
        source: "TNegative"
      },
      inconclusive_total: {
        name: "Inconclusive Test Results - Total",
        highlight: false,
        source: "TInconc"
      },
      monitored_cumulative: {
        name: "Monitored - Cumulative Total",
        highlight: false,
        source: "EverMon"
      },
      monitored_currently: {
        name: "Monitored - Current Total",
        highlight: false,
        source: "MonNow"
      },
      positives_total: {
        name: "Positive Tests - Total",
        description: "Florida and non-Florida residents, including residents tested outside of the Florida, and at private facilities.",
        highlight: true,
        source: "T_positive"
      },
      negatives_total: {
        name: "Negative Tests - Total",
        description: "Florida and non-Florida residents, including residents tested outside of the Florida, and at private facilities.",
        highlight: true,
        source: "T_negative"
      },
      pending_total: {
        name: "Pending Tests - Total",
        description: "Test administered but results pending.",
        highlight: true,
        source: "TPending"
      },
      cumulative_hospitalized: {
        name: "Hospitalized (cumulative)",
        description: "Hospitalization occurred at any time during illness. Not count of current hospitalizations.",
        highlight: true,
        source: "C_Hosp_Yes"
      },
      tests_total: {
        name: "Tests - Total",
        description: "Individuals tested with results obtained or pending.",
        highlight: true,
        source: "T_total"
      },
      PUIs_total: {
        name: "PUIs - Total",
        description: "Any person who has been or is waiting to be tested.",
        highlight: true,
        source: "PUIsTotal"
      },
      deaths_residents: {
        name: "Deaths - Residents",
        highlight: true,
        source: "FLResDeaths"
      },
      deaths_non_residents: {
        name: "Deaths - Non-residents",
        highlight: false,
        source: "C_NonResDeaths"
      }
    }
  end

  def self.production?
    ENV["RACK_ENV"] == "production"
  end

  def self.development?
    !production?
  end

  def self.cache
    @redis ||= if production?
      Redis.new(url: ENV["REDIS_URL"])
    else
      Redis.new
    end
  end

  def self.check_cache(key)
    payload = cache.get(key)

    if payload
      puts "cache hit for #{key}"
      JSON.parse(payload, { symbolize_names: true })
    else
      puts "cache miss for #{key}"
    end
  end

  def self.write_cache(key, value)
    puts "cache write for #{key}"
    payload = value.to_json
    puts "caching serialized payload: #{payload.inspect}"

    cache.multi do
      cache.set(key, payload)
      cache.get(key)
    end
  end

  def self.set_expiration(key, time)
    cache.expireat(key, time.to_i)
  end

  def self.nomenclature
    <<~HTML
      <h2>Nomenclature</h2>
      <p>
        Referenced from <a href="https://fdoh.maps.arcgis.com/home/item.html?id=8d0de33f260d444c852a615dc7837c86">Florida COVID-19 Confirmed Cases</a>.
      </p>

      <dl>
        <dt>PUI</dt>
        <dd>
          Essentially, PUIs are any person who has been or is waiting
          to be tested. This includes: persons who are considered
          high-risk for COVID-19 due to recent travel, contact with a
          known case, exhibiting symptoms of COVID-19 as determined by
          a healthcare professional, or some combination thereof.
          PUI’s also include people who meet laboratory testing
          criteria based on symptoms and exposure, as well as
          confirmed cases with positive test results. PUIs include any
          person who is or was being tested, including those with
          negative and pending results.
        </dd>

        <dt>Monitored</dt>
        <dd>
          People the Florida Department of Health was notified of for
          possible monitoring because they are a contact of a case,
          recently traveled to an area with community spread, or were
          identified by the Centers for Disease Control and Prevention
          (CDC) as a part of an airline/ship contact investigation.
          Not all persons who were initially reported are still
          monitored, depending on their circumstances, negative test
          results, or continued period of no symptoms.
        </dd>

        <dt>Hospitalization</dt>
        <dd>
          Count of all laboratory confirmed cases in which an
          inpatient hospitalization occurred at any time during the
          course of illness. These people my no longer be hospitalized.
          This number does not represent the number of COVID-19 positive
          persons currently hospitalized. We do not have a figure for
          that information at this time.
        </dd>
      </dl>
    HTML
  end
end
