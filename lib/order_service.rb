# frozen_string_literal: true

# OrderService module
module OrderService
  def self.create_order_v2(params, tracking_number, couch_id)
    couch_order = 0
    ActiveRecord::Base.transaction do
      npid = params[:patient][:id]
      patient_obj = Patient.where(patient_number: npid)
      patient_obj = patient_obj.first unless patient_obj.blank?

      if patient_obj.blank?
        patient_obj = patient_obj.create(
          patient_number: npid,
          name: params[:patient][:first_name] + ' ' + params[:patient][:last_name],
          email: '',
          dob: params[:patient][:date_of_birth],
          gender: params[:patient][:gender],
          phone_number: params[:patient][:phone_number],
          address: '',
          external_patient_number: ''
        )
      end
      sample_status = {}
      test_status = {}
      time = params[:date_created]
      sample_status[time] = {
        'status' => 'Drawn',
        "updated_by": {
          first_name: params[:who_order_test][:first_name],
          last_name: params[:who_order_test][:last_name],
          phone_number: params[:patient][:phone_number],
          id: params[:who_order_test][:id]
        }
      }

      sample_type_id = SpecimenType.get_specimen_type_id(params[:sample_type])
      sample_status_id = SpecimenStatus.get_specimen_status_id(params[:sample_status])

      sp_obj = Speciman.create(
        tracking_number: tracking_number,
        specimen_type_id: sample_type_id,
        specimen_status_id: sample_status_id,
        couch_id: '',
        ward_id: Ward.get_ward_id(params[:order_location]),
        priority: params[:priority],
        drawn_by_id: params[:who_order_test][:id],
        drawn_by_name: params[:who_order_test][:first_name].to_s + ' ' + params[:who_order_test][:last_name].to_s,
        drawn_by_phone_number: params[:patient][:phone_number],
        target_lab: params[:receiving_facility],
        art_start_date: Time.now,
        sending_facility: params[:sending_facility],
        requested_by: params[:requesting_clinician],
        district: params[:district],
        date_created: time
      )

      res = Visit.create(
        patient_id: npid,
        visit_type_id: '',
        ward_id: Ward.get_ward_id(params[:order_location])
      )
      var_checker = false

      params[:tests].each do |tst|
        tst = tst.gsub('&amp;', '&')
        tstt = health_data_tests_types(tst)
        status = check_test(tstt)
        if status == false
          details = {}
          details[time] = {
            'status' => 'Drawn',
            "updated_by": {
              first_name: params[:who_order_test][:first_name],
              last_name: params[:who_order_test][:last_name],
              phone_number: params[:patient][:phone_number],
              id: params[:who_order_test][:id]
            }
          }
          test_status[tst] = details
          rst = TestType.get_test_type_id(tstt)
          rst2 = TestStatus.get_test_status_id('drawn')

          t = Test.create(
            specimen_id: sp_obj.id,
            test_type_id: rst,
            patient_id: patient_obj.id,
            created_by: params[:who_order_test][:first_name].to_s + ' ' + params[:who_order_test][:last_name].to_s,
            panel_id: '',
            time_created: time,
            test_status_id: rst2
          )
          if !params[:test_results].blank? && !r = params[:test_results][tst].blank?
            r = params[:test_results][tst]
            r = r['results']

            measure_name = r.keys
            measure_name.each do |m|
              v = r[m]
              r_value = v[:result_value]
              date = v[:date_result_entered]
              next if m.blank?

              mm = check_health_data_measures(m)
              m = Measure.where(name: mm).first
              m = m.id
              TestResult.create(
                test_id: t.id,
                measure_id: m,
                result: r_value,
                time_entered: date,
                device_name: ''
              )
            end
            var_checker = true
          end

          if var_checker == true
            ts_st = TestStatus.where(name: 'verified').first
            tv = Test.find_by(id: t.id)
            tv.test_status_id = ts_st.id
            tv.save
            var_checker = false
          end
        else
          pa_id = PanelType.where(name: tstt).first
          res = TestType.find_by_sql("SELECT test_types.id FROM test_types INNER JOIN panels
                                                      ON panels.test_type_id = test_types.id
                                                      INNER JOIN panel_types ON panel_types.id = panels.panel_type_id
                                                      WHERE panel_types.id ='#{pa_id.id}'")
          res.each do |tt|
            details = {}
            details[time] = {
              'status' => 'Drawn',
              "updated_by": {
                first_name: params[:who_order_test][:first_name],
                last_name: params[:who_order_test][:last_name],
                phone_number: params[:patient][:phone_number],
                id: params[:who_order_test][:id]
              }
            }
            test_status[tst] = details
            # rst = TestType.get_test_type_id(tt)
            rst2 = TestStatus.get_test_status_id('drawn')
            updater = begin
              params[:who_order_test][:first_name] + ' ' + params[:who_order_test][:last_name]
            rescue StandardError
              nil
            end
            t = Test.create(
              specimen_id: sp_obj.id,
              test_type_id: tt.id,
              patient_id: patient_obj.id,
              created_by: updater,
              panel_id: '',
              time_created: time,
              test_status_id: rst2
            )

            if !params[:test_results].blank? && !params[:test_results][tst].blank?
              r = params[:test_results][tst]
              r = r['results']
              measure_name = r.keys
              measure_name.each do |m|
                v = r[m]
                r_value = v[:result_value]
                date = v[:date_result_entered]
                next if m.blank?

                mm = check_health_data_measures(m)
                m = Measure.where(name: mm).first
                m = m.id
                TestResult.create(
                  test_id: t.id,
                  measure_id: m,
                  result: r_value,
                  time_entered: date,
                  device_name: ''
                )
              end
              var_checker = true
            end

            next unless var_checker == true

            ts_st = TestStatus.where(name: 'verified').first
            tv = Test.find_by(id: t.id)
            tv.test_status_id = ts_st.id
            tv.save
            var_checker = false
          end
        end
      end

      sp = Speciman.find_by(tracking_number: tracking_number)
      sp.couch_id = couch_id
      sp.save
      couch_order = couch_id
    end

    [true, tracking_number, couch_order]
  end

  def self.health_data_tests_types(name)
    if name == 'Hep'
      'Hepatitis C Test'
    elsif  name == 'LFT'
      'Liver Function Tests'
    elsif  name  == 'Creat'
      'Creatinine Kinase'
    elsif  name  == 'Urinanal'
      'Urine Macroscopy'
    elsif  name  == 'MP'
      'Microprotein'
    elsif  name  == 'Full CSF analysis'
      'CSF Analysis'
    elsif  name  == 'Full CSF'
      'CSF Analysis'
    elsif  name  == 'Lactate'
      'Lipogram'
    elsif  name  == 'Crypto AG'
      'Cryptococcus Antigen Test'
    elsif  name  == 'U/E'
      'Uric Acid'
    elsif  name  == 'Full stool analysis'
      'Stool Analysis'
    elsif  name  == 'VDRL'
      'Viral Load'
    elsif name == 'HIV_viral_load'
      'Viral Load'
    elsif  name  == 'Cholest'
      'Urine Chemistries'
    elsif  name  == 'RBS'
      'FBC'
    elsif  name  == 'Tg'
      'TT'
    elsif  name  == 'Uri C/S'
      'Urine Microscopy'
    elsif  name  == 'AAFB (2nd)'
      'Uric Acid'
    elsif  name  == 'AAFB (1nd)'
      'Uric Acid'
    elsif  name  == 'AAFB (3nd)'
      'Uric Acid'
    elsif  name  == 'AAFB 4nd)'
      'Uric Acid'
    elsif  name  == 'AAFB (5nd)'
      'Uric Acid'
    elsif  name  == 'Blood NOS'
      'FBC'
    elsif  name  == 'G/XM'
      'Urine Microscopy'
    else
      name
    end
  end

  def self.check_health_data_measures(m)
    if m == 'CD4_count'
      'CD4` Count'
    elsif m == 'Bilirubin_total'
      'Bilirubin Total(BIT))'
    elsif m == 'Bilirubin_total'
      'Bilirubin Total(BIT))'
    elsif m == 'Gamma Glutamyl transpeptidase'
      'Lipase'
    elsif m == 'Alanine_Aminotransferase'
      'Lipase'
    elsif m == 'Aspartate_Transaminase'
      'Lipase'
    elsif m == 'CD3_percent'
      'CD4 %'
    elsif m == 'HIV_RNA_PCR'
      'Viral Load'
    elsif m == 'CD4_percent'
      'CD4 %'
    elsif  m == 'CD8_percent'
      'CD4 %'
    elsif  m == 'CD8Tube'
      'CD4 %'
    elsif  m == 'CD8Tube'
      'CD4 Count'
    elsif  m == 'WBC_percent'
      'WBC'
    elsif m == 'RBC'
      'RBC'
    elsif  m == 'RDW'
      'RDW-CV'
    elsif  m == 'Platelet_count'
      'Platelet Comments'
    elsif  m == 'Phosphorus'
      'Phosphorus (PHOS)'
    elsif m == 'Neutrophil_percent'
      'Neutrophils'
    elsif m == 'Neutrophil_count'
      'Neutrophils'
    elsif m == 'Monocyte_count'
      'Monocytes'
    elsif m == 'Malaria_Parasite_count'
      'Malaria Species'
    elsif  m == 'Lymphocyte_percent'
      'Lymphocytes'
    elsif  m == 'Lymphocyte_count'
      'Lymphocyte Count'
    elsif m == 'Lactate'
      'Lactatedehydrogenase(LDH)'
    elsif  m == 'HepBsAg'
      'Hepatitis B'
    elsif  m == 'Hemoglobin'
      'HB'
    elsif m == 'WBC_count'
      'WBC'
    elsif m == 'Glucose_CSF'
      'Glucose'
    elsif  m == 'Glucose_blood'
      'Glucose'
    elsif  m == 'Eosinophil_percent'
      'Eosinophils'
    elsif m == 'Eosinophil_count'
      'Eosinophils'
    elsif m == 'Cryptococcal_Antigen'
      'CrAg'
    elsif m == 'Cholesterol'
      'Cholestero l(CHOL)'
    elsif m == 'Urea_Nitrogen_blood'
      'Glucose'
    elsif m == 'Basophil_percent'
      'Basophils'
    elsif m == 'Basophil_count'
      'Basophils'
    elsif m == 'Monocyte_percent'
      'Monocytes'
    elsif m == 'Hematocrit'
      'HB'
    elsif m == 'Triglycerides'
      'Triglycerides(TG)'
    elsif m == 'Toxoplasma_IgG'
      '50:50 Normal Plasma'
    elsif  m == 'Protein_total'
      'Total Proteins'
    elsif m == 'CD8_count'
      'CD8 Count'
    elsif m == 'Albumin'
      'Albumin(ALB)'
    elsif m == 'India_Ink'
      'India Ink'
    elsif m == 'Alkaline_Phosphatase'
      'Alkaline Phosphate(ALP)'
    elsif m == 'Bilirubin_direct'
      'Bilirubin Direct(BID)'
    elsif m == 'Glutamyl_Transferase'
      'GGT/r-GT'
    elsif m == 'CD8_CD3_ratio'
      'CD8 Count'
    elsif m == 'CD4_CD3_ratio'
      'CD4 Count'
    elsif m == 'CD4_CD8_ratio'
      'CD8 Count'
    elsif m == 'Carbon_Dioxide'
      'Other'
    elsif m == 'CD3_count'
      'CD3 Count'
    elsif m == 'RPR_Syphilis'
      'VDRL'
    elsif m == 'CD4 lube'
      'CD4 Count'
    elsif m == 'ControlRunControlLotID'
      'Control'
    else
      m
    end
  end

  def self.check_test(tst)
    res = PanelType.find_by_sql("SELECT * FROM panel_types WHERE name ='#{tst}'")

    return true if res.length > 0

    false
  end

  def self.check_data_anomalies(doc)
    specimen_type = doc['doc']['sample_type']
    tests = doc['doc']['tests']
    status = true
    res = ''
    res = SpecimenType.find_by_sql("SELECT * FROM specimen_types WHERE name ='#{specimen_type}'")
    if res.blank?
      DataAnomaly.create(
        data_type: 'specimen type',
        data: specimen_type,
        site_name: doc['doc']['sending_facility'],
        tracking_number: doc['doc']['tracking_number'],
        couch_id: doc['doc']['_id'],
        date_created: Time.new.strftime('%Y%m%d%H%M%S'),
        status: 'not-resolved'
      )
      status = false
    end
    tests.each do |test_type|
      test_type = 'Cross-Match' if test_type == 'Cross Match'
      res = TestType.find_by_sql("SELECT * FROM test_types WHERE name ='#{test_type}'")
      next unless res.blank?

      DataAnomaly.create(
        data_type: 'test type',
        data: test_type,
        site_name: doc['doc']['sending_facility'],
        tracking_number: doc['doc']['tracking_number'],
        couch_id: doc['doc']['_id'],
        date_created: Time.new.strftime('%Y%m%d%H%M%S'),
        status: 'not-resolved'
      )
      status = false
    end

    status
  end

  def self.create_order(document, tracking_number, couch_id)
    return [false, 'not an order'] if document['doc']['error'] == 'not_found'

    documentx = document
    document = document['doc']
    patient_id = document['patient']['id']
    patient_f_name = document['patient']['first_name']
    patient_l_name = document['patient']['last_name']
    patient_gender = document['patient']['gender']
    patient_email = document['patient']['email']
    patient_phone = document['patient']['phone_number']
    patient_dob = document['patient']['dob']
    ward = document['order_location']
    district = document['district']
    puts "Created date #{document['date_created']}"
    date_created = document['date_created'] unless document['date_created'].blank?
    date_created = Time.now if document['date_created'] == '0000-00-00 00:00:00'
    priority = document['priority']
    receiving_facility = document['receiving_facility']
    sample_status = document['sample_status']
    sample_type = document['sample_type']
    sending_facility = document['sending_facility']

    return [false, 'its an order request'] if sample_type.blank?
    return [false, 'its an order request'] if sample_type == 'not_assigned'
    return [false, 'its an order request'] if sample_type == 'not_specified'

    who_order_id = begin
      document['who_order_test']['id']
    rescue StandardError
      ''
    end
    who_order_f_name = begin
      document['who_order_test']['first_name']
    rescue StandardError
      ''
    end
    who_order_l_name = begin
      document['who_order_test']['last_name']
    rescue StandardError
      ''
    end
    who_order_phone_number = begin
      document['who_order_test']['phone_number']
    rescue StandardError
      ''
    end

    begin
      ward_id = OrderService.get_ward_id(ward)
      sample_type_id = OrderService.get_specimen_type_id(sample_type)
      sample_status_id = OrderService.get_specimen_status_id(sample_status)
      arv_number = ''
      art_regimen = ''

      art_regimen = document['art_regimen'] unless document['art_regimen'].blank?
      arv_number = document['arv_number'] unless document['art_regimen'].blank?

      pat_date = document['art_start_date']
      ActiveRecord::Base.transaction do
        sp = Speciman.create(
          tracking_number: tracking_number,
          specimen_type_id: sample_type_id,
          specimen_status_id: sample_status_id,
          couch_id: couch_id,
          priority: priority,
          drawn_by_id: who_order_id,
          drawn_by_name: who_order_f_name + ' ' + who_order_l_name,
          drawn_by_phone_number: who_order_phone_number,
          target_lab: receiving_facility,
          art_start_date: pat_date,
          sending_facility: sending_facility,
          requested_by: '',
          ward_id: 1,
          district: district,
          date_created: date_created,
          art_regimen: art_regimen,
          arv_number: arv_number
        )

        tests = document['test_statuses']
        patient_obj = Patient.where(patient_number: patient_id)
        patient_obj = patient_obj.first unless patient_obj.blank?
        if patient_obj.blank?
          patient_obj = patient_obj.create(
            patient_number: patient_id,
            name: patient_f_name + ' ' + patient_l_name,
            email: patient_email,
            dob: patient_dob,
            gender: patient_gender,
            phone_number: patient_phone,
            address: '',
            external_patient_number: ''
          )
        else
          patient_obj.dob = patient_dob
          patient_obj.save
        end
        p_id = patient_obj.id
        tests.each do |tst_name, tst_value|
          tst_name = 'ABO Blood Grouping' if tst_name == 'Abo Blood Grouping'
          tst_name = 'Cross-match' if tst_name == 'Cross Match'
          tst_name = 'CrAg' if tst_name == 'Cr Ag'
          tst_name = 'Cryptococcus Antigen Test' if tst_name == 'Cryptococcal Antigen'
          tst_name = 'FBC' if tst_name == 'Fbs'
          tst_name = 'Creatine' if tst_name == 'Creat'
          tst_name = 'Early Infant Diagnosis' if tst_name == 'EID'
          test_id = OrderService.get_test_type_id(tst_name)
          test_status = tst_value[tst_value.keys[tst_value.keys.count - 1]]['status']
          test_status_id = OrderService.get_status_id(test_status)
          updated_by_id = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['id']
          updated_by_first_name = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['first_name']
          updated_by_last_name = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['last_name']
          updated_by_phone_number = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['phone_number']

          tst_obj = Test.create(
            specimen_id: sp.id,
            test_type_id: test_id,
            patient_id: p_id,
            created_by: who_order_f_name + ' ' + who_order_l_name,
            panel_id: '',
            time_created: date_created,
            test_status_id: test_status_id
          )

          tst_value.each do |_updated_at, value|
            status = value['status']
            updated_by_id = value['updated_by']['id']
            updated_by_f_name = value['updated_by']['first_name']
            updated_by_l_name = value['updated_by']['last_name']
            updated_by_phone_number = value['updated_by']['phone_number']
            test_status_id = OrderService.get_status_id(status)
            TestStatusTrail.create(
              test_id: tst_obj.id,
              time_updated: date_created,
              test_status_id: test_status_id,
              who_updated_id: updated_by_id.to_s,
              who_updated_name: updated_by_f_name.to_s + ' ' + updated_by_l_name.to_s,
              who_updated_phone_number: updated_by_phone_number
            )
          end

          test_results = document['test_results'][tst_name]

          next unless !test_results.blank? && (test_results['results'].keys.count > 0)

          test_results['results'].keys.each do |ms|
            ms = 'Bilirubin Total(TBIL-VOX)' if ms == 'TBIL-VOX'
            ms = 'Bilirubin Direct(DBIL-VOX)' if ms == 'DBIL-VOX'
            measur_id = OrderService.get_measure_id(ms)
            rst = test_results['results'][ms]
            TestResult.create(
              measure_id: measur_id,
              test_id: tst_obj.id,
              result: rst['result_value'],
              device_name: '',
              time_entered: ''
            )
          end
        end
        puts '---------done------------'
      end
    rescue StandardError => e
      puts e
      check_data_anomalies(documentx)
    end
  end

  def self.check_order(tracking_number)
    res = Speciman.find_by_sql("SELECT id AS track_id FROM specimen WHERE tracking_number='#{tracking_number}'")
    return true unless res.blank?

    false
  end

  def self.save_visit(npid, visit_type, ward)
    obj = Visit.create(
      patient_id: npid,
      visit_type_id: visit_type,
      ward_id: ward
    )
    obj.id
  end

  def self.get_ward_id(ward_name)
    ward_name = ward_name.gsub("'", '')
    Ward.find_or_create_by(name: ward_name).id
  end

  def self.get_test_type_id(name)
    res = TestType.find_by_sql("SELECT id AS test_id FROM test_types WHERE name='#{name}'")
    return if res.blank?

    res[0]['test_id']
  end

  def self.get_status_id(name)
    res = TestStatus.find_by_sql("SELECT id AS status_id FROM test_statuses WHERE name='#{name}'")
    return if res.blank?

    res[0]['status_id']
  end

  def self.get_measure_id(name)
    res = Measure.find_by_sql("SELECT id AS measure_id FROM measures WHERE name='#{name}'")
    return if res.blank?

    res[0]['measure_id']
  end

  def self.get_specimen_type_id(name)
    res = SpecimenType.find_by_sql("SELECT id AS spc_id FROM specimen_types WHERE name='#{name}'")
    return if res.blank?

    res[0]['spc_id']
  end

  def self.get_specimen_status_id(name)
    res = SpecimenStatus.find_by_sql("SELECT id AS spc_id FROM specimen_statuses WHERE name='#{name}'")
    return if res.blank?

    res[0]['spc_id']
  end

  def self.update_order(document, tracking_number)
    puts 'migrating v2--------------------------------'
    puts tracking_number
    document = document['doc']
    patient_id = document['patient']['id']
    patient_f_name = document['patient']['first_name']
    patient_l_name = document['patient']['last_name']
    patient_gender = document['patient']['gender']
    patient_email = document['patient']['email']
    patient_phone = document['patient']['phone_number']

    ward = document['order_location']
    district = document['districy']
    begin
      date_created = document['date_created'] unless document['date_created'].blank?
    rescue ArgumentError
      date_created = Time.new
    end
    priority = document['priority']
    receiving_facility = document['receiving_facility']
    sample_status = document['sample_status']
    sample_type = document['sample_type']
    sending_facility = document['sending_facility']

    who_order_id = document['who_order_test']['id']
    who_order_f_name = document['who_order_test']['first_name']
    who_order_l_name = document['who_order_test']['last_name']
    who_order_phone_number = document['who_order_test']['phone_number']

    ward_id = OrderService.get_ward_id(ward)

    sample_type_id = OrderService.get_specimen_type_id(sample_type)
    sample_status_id = OrderService.get_specimen_status_id(sample_status)

    Speciman.where(tracking_number: tracking_number).update_all(
      tracking_number: tracking_number,
      specimen_type_id: sample_type_id,
      specimen_status_id: sample_status_id,
      priority: priority,
      drawn_by_id: who_order_id,
      drawn_by_name: who_order_f_name + ' ' + who_order_l_name,
      drawn_by_phone_number: who_order_phone_number,
      target_lab: receiving_facility,
      art_start_date: Time.now,
      sending_facility: sending_facility,
      ward_id: ward_id,
      requested_by: '',
      district: district,
      date_created: date_created
    )
    sp = Speciman.find_by(tracking_number: tracking_number)
    patient_obj = Patient.where(patient_number: patient_id)
    patient_obj = patient_obj.first unless patient_obj.blank?
    if patient_obj.blank?
      patient_obj = patient_obj.create(
        patient_number: patient_id,
        name: patient_f_name + ' ' + patient_l_name,
        email: patient_email,
        dob: Time.new.strftime('%Y%m%d%H%M%S'),
        gender: patient_gender,
        phone_number: patient_phone,
        address: '',
        external_patient_number: ''
      )
    end
    p_id = patient_obj.id
    tests = document['test_statuses']
    tests.each do |tst_name, tst_value|
      test_results = document['test_results'][tst_name]
      tst_name = 'Cross-match' if tst_name == 'Cross Match'
      tst_name = 'ABO Blood Grouping' if tst_name == 'Abo Blood Grouping'
      tst_name = 'Early Infant Diagnosis' if tst_name == 'EID'
      test_id = OrderService.get_test_type_id(tst_name)
      test_status = tst_value[tst_value.keys[tst_value.keys.count - 1]]['status']
      test_status_id = OrderService.get_status_id(test_status)
      updated_by_id = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['id']
      updated_by_first_name = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['first_name']
      updated_by_last_name = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['last_name']
      updated_by_phone_number = tst_value[tst_value.keys[tst_value.keys.count - 1]]['updated_by']['phone_number']
      tst_obj = Test.where(specimen_id: sp.id, test_type_id: test_id).first
      if tst_obj.blank?
        tst_obj = Test.create(
          specimen_id: sp.id,
          test_type_id: test_id,
          patient_id: p_id,
          created_by: who_order_f_name + ' ' + who_order_l_name,
          panel_id: '',
          time_created: date_created,
          test_status_id: test_status_id
        )
      end
      Test.where(specimen_id: sp.id, test_type_id: test_id).update_all(
        specimen_id: sp.id,
        test_type_id: test_id,
        patient_id: p_id,
        created_by: who_order_f_name + ' ' + who_order_l_name,
        panel_id: '',
        time_created: date_created,
        test_status_id: test_status_id
      )

      unless document['results_acknowledgement'].blank?

        document['results_acknowledgement'].each do |t_name, _t_values|
          fnd_id = OrderService.get_test_type_id(tst_name)
          next unless fnd_id == test_id
          rst_type = TestResultRecepientType.find_by(name: document['results_acknowledgement'][t_name]['result_recepient_type'])
          rst_given = document['results_acknowledgement'][t_name]['result_given']
          rst_given = if rst_given == 'true'
                        1
                      else
                        0
                      end
          Test.where(specimen_id: sp.id, test_type_id: test_id).update_all(
            specimen_id: sp.id,
            test_type_id: test_id,
            patient_id: p_id,
            created_by: who_order_f_name + ' ' + who_order_l_name,
            panel_id: '',
            time_created: date_created,
            test_status_id: test_status_id,
            test_result_receipent_types: rst_type['id'],
            result_given: rst_given,
            date_result_given: document['results_acknowledgement'][t_name]['date_result_give;'].to_time
          )
        end

      end

      count = tst_value.keys.count
      puts tst_name
      t_tst_id_ =  tst_obj.id
      t_count = TestStatusTrail.find_by_sql("SELECT count(*) AS t_count FROM test_status_trails WHERE test_id='#{t_tst_id_}'")[0]['t_count']

      unless t_count.blank?
        if ((count - t_count) == 1) && count > t_count
          value = tst_value[tst_value.keys[count - 1]]
          status = value['status']
          updated_by_id = value['updated_by']['id']
          updated_by_f_name = value['updated_by']['first_name']
          updated_by_l_name = value['updated_by']['last_name']
          updated_by_phone_number = value['updated_by']['phone_number']
          test_status_id = OrderService.get_status_id(status)
          test_i = test_id
          TestStatusTrail.create(
            test_id: tst_obj.id,
            time_updated: date_created,
            test_status_id: test_status_id,
            who_updated_id: updated_by_id.to_s,
            who_updated_name: updated_by_f_name.to_s + ' ' + updated_by_l_name.to_s,
            who_updated_phone_number: updated_by_phone_number
          )
        elsif ((count - t_count) > 1) && count > t_count
          control = 0
          tst_value.each do |_updated_at, value|
            control += 1
            next if control <= t_count

            status = value['status']
            updated_by_id = value['updated_by']['id']
            updated_by_f_name = value['updated_by']['first_name']
            updated_by_l_name = value['updated_by']['last_name']
            updated_by_phone_number = value['updated_by']['phone_number']
            test_status_id = OrderService.get_status_id(status)
            test_i = test_id
            TestStatusTrail.create(
              test_id: tst_obj.id,
              time_updated: date_created, # updated at
              test_status_id: test_status_id,
              who_updated_id: updated_by_id.to_s,
              who_updated_name: updated_by_f_name.to_s + ' ' + updated_by_l_name.to_s,
              who_updated_phone_number: updated_by_phone_number
            )
          end
        end
      end

      next unless !test_results.blank? && (test_results['results'].keys.count > 0)

      test_results['results'].keys.each do |ms|
        measur_id = OrderService.get_measure_id(ms)
        rst = test_results['results'][ms]
        res = TestResult.find_by_sql("SELECT count(*) AS t_count FROM test_results WHERE measure_id='#{measur_id}' AND test_id='#{tst_obj.id}'")[0]
        if res['t_count'] != 0
          TestResult.where(measure_id: measur_id, test_id: tst_obj.id).update_all(
            measure_id: measur_id,
            test_id: tst_obj.id,
            result: rst['result_value'],
            device_name: '',
            time_entered: rst['date_result_entered'] || test_results['date_result_entered']
          )
        else
          TestResult.create(
            measure_id: measur_id,
            test_id: tst_obj.id,
            result: rst['result_value'],
            device_name: '',
            time_entered: rst['date_result_entered'] || test_results['date_result_entered']
          )
        end
      end
    end
  rescue StandardError => e
    puts e
  end
end
