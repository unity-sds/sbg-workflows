#!/usr/bin/env cwl-runner
cwlVersion: v1.1
class: Workflow
label: Workflow that executes the SBG L1 Workflow

$namespaces:
  cwltool: http://commonwl.org/cwltool#

requirements:
  SubworkflowFeatureRequirement: {}
  ScatterFeatureRequirement: {}
  InlineJavascriptRequirement: {}
  StepInputExpressionRequirement: {}
  MultipleInputFeatureRequirement: {}


## Inputs to the e2e rebinning, not to each applicaiton within the workflow
inputs:

  # Generic inputs
  input_processing_labels: string[]

  # For CMR Search Step
  input_cmr_collection_name: string
  input_cmr_search_start_time: string
  input_cmr_search_stop_time: string

  # catalog inputs
  input_unity_dapa_api: string
  input_unity_dapa_client: string

  #for preprocess  step
  input_crid: string

  #isofit step
  input_cores: int

  input_aux_stac:
    - string
    - File

  # For unity data stage-out step, unity catalog
  output_preprocess_collection_id: string
  output_isofit_collection_id: string
  #output_resample_collection_id: string
  #output_refcorrect_collection_id: string
  #output_frcover_collection_id: string
  output_data_bucket: string


outputs: 
  results: 
    type: File
    outputSource: preprocess/stage_out_results

steps:
  cmr-step:
    run: http://awslbdockstorestack-lb-1429770210.us-west-2.elb.amazonaws.com:9998/api/ga4gh/trs/v2/tools/%23workflow%2Fdockstore.org%2Fmike-gangl%2Fcmr-trial/versions/4/PLAIN-CWL/descriptor/%2FDockstore.cwl
    in:
      cmr_collection : input_cmr_collection_name
      cmr_start_time: input_cmr_search_start_time
      cmr_stop_time: input_cmr_search_stop_time
      # # Need to understand the best way of inputting this credential, nullables
      # cmr_edl_user: "null"
      # cmr_edl_pass: "null"
    out: [results]
  preprocess:
    run: http://awslbdockstorestack-lb-1429770210.us-west-2.elb.amazonaws.com:9998/api/ga4gh/trs/v2/tools/%23workflow%2Fdockstore.org%2Fmike-gangl%2FSBG-unity-preprocess/versions/23/PLAIN-CWL/descriptor/%2Fworkflow.cwl
    in:
      # input configuration for stage-in
      # edl_password_type can be either 'BASE64' or 'PARAM_STORE' or 'PLAIN'
      # README available at https://github.com/unity-sds/unity-data-services/blob/main/docker/Readme.md
      stage_in:
        source: [cmr-step/results, input_unity_dapa_client]
        valueFrom: |
          ${
              return {
                download_type: 'DAAC',
                stac_json: self[0],
                edl_password: '/sps/processing/workflows/edl_password',
                edl_username: '/sps/processing/workflows/edl_username',
                edl_password_type: 'PARAM_STORE',
                downloading_keys: 'data, data1',
                downloading_roles: '',
                unity_stac_auth: 'NONE',
                unity_client_id: self[1],
                log_level: '10'
              };
          }
      #input configuration for process
      parameters:
        source: [output_preprocess_collection_id, input_crid]
        valueFrom: |
          ${
              return {
                crid: self[1],
                sensor: 'EMIT',
                temp_directory: '/tmp',
                output_collection: self[0]
              };
          }
      #input configuration for stage-out
      # readme available at https://github.com/unity-sds/unity-data-services/blob/main/docker/Readme.md
      stage_out:
        source: [output_data_bucket, output_preprocess_collection_id]
        valueFrom: |
          ${
              return {
                aws_access_key_id: '',
                aws_region: 'us-west-2',
                aws_secret_access_key: '',
                aws_session_token: '',
                collection_id: self[1],
                staging_bucket: self[0],
                log_level: '20',
                result_path_prefix: 'stage_out'
              };
          }
    out: [stage_out_results, stage_out_success, stage_out_failures]

  isofit:
    run: http://awslbdockstorestack-lb-1429770210.us-west-2.elb.amazonaws.com:9998/api/ga4gh/trs/v2/tools/%23workflow%2Fdockstore.org%2Fmike-gangl%2FSBG-unity-isofit/versions/20/PLAIN-CWL/descriptor/%2Fworkflow.cwl
    in:
      # input configuration for stage-in
      # edl_password_type can be either 'BASE64' or 'PARAM_STORE' or 'PLAIN'
      # README available at https://github.com/unity-sds/unity-data-services/blob/main/docker/Readme.md
      stage_in:
        source: [preprocess/stage_out_success, input_unity_dapa_client]
        valueFrom: |
          ${
              return {
                download_type: 'S3',
                stac_json: self[0],
                unity_stac_auth: 'NONE',
                unity_client_id: self[1],
                downloading_roles: 'data, metadata',
                log_level: '20'
              };
          }
      #input configuration for process
      stage_aux_in:
        source: [input_aux_stac, input_unity_dapa_client]
        valueFrom: |
          ${
              return {
                download_type: 'S3',
                stac_json: self[0],
                unity_stac_auth: 'NONE',
                unity_client_id: self[1],
                downloading_roles: 'data, metadata',
                log_level: '20'
              };
          }
      parameters:
        source: [output_isofit_collection_id, input_crid, input_cores]
        valueFrom: |
          ${
              return {
                crid: self[1],
                cores: self[2],
                sensor: 'EMIT',
                temp_directory: '/tmp',
                output_collection: self[0]
              };
          }
      #input configuration for stage-out
      # readme available at https://github.com/unity-sds/unity-data-services/blob/main/docker/Readme.md
      stage_out:
        source: [output_data_bucket, output_isofit_collection_id]
        valueFrom: |
          ${
              return {
                aws_access_key_id: '',
                aws_region: 'us-west-2',
                aws_secret_access_key: '',
                aws_session_token: '',
                collection_id: self[1],
                staging_bucket: self[0],
                log_level: '20',
                result_path_prefix: 'stage_out'
              };
          }
    out: [stage_out_results, stage_out_success, stage_out_failures]

 
