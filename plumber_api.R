# Load required packages
library(plumber)
library(dplyr)
library(glue)
library(gargle)
library(rmarkdown)
library(googleCloudStorageR)
library(tools)

# Load environment variables from .env if it exists
bucket <- Sys.getenv("GCS_BUCKET_NAME")

# Define config ----------------------------------------------------------------
report_config <- tribble(
  ~code,  ~box_folder_id, ~rmd_name,                      ~pdf_name,
  "roi_pa", "310990504598", "weekly_roi_physical_activity_metrics.Rmd",              "Connect_Weekly_ROI_Metrics_Report.pdf"
  "roi_qc", "311600212691", "ROI_Custom_QC.Rmd",              "Connect_Weekly_ROI_QC_Report.pdf"
)

# Global Decorators ------------------------------------------------------------
#* @apiTitle Demo pipeline API
#* @apiDescription Plumber API for generating and uploading reports.

# Endpoint A -------------------------------------------------------------------
#* Heartbeat endpoint for testing
#* @get /heartbeat
function() {
  msg <- "API is alive!"
  message(msg)
}

# Endpoint B -------------------------------------------------------------------
#* Generate report and upload to GCS
#* @param report:string The code of the report as specified in the config
#* @get /render_rmd_report
function(report) {
  
  # Get the configuration associated with the report code
  cfg <- report_config %>% filter(code == report)
  
  # Generate a unique PDF filename
  date_stamp <- format(Sys.time(), "%m_%d_%Y")
  base_name  <- tools::file_path_sans_ext(cfg$pdf_name)
  pdf_name   <- glue::glue("{base_name}_{date_stamp}_boxfolder_{cfg$box_folder_id}.pdf")
  
  # Render the RMarkdown file
  rmarkdown::render(cfg$rmd_name, output_format="pdf_document", output_file=pdf_name)
  
  # Authenticate with Google Cloud Storage
  scope <- c("https://www.googleapis.com/auth/cloud-platform")
  token <- gargle::token_fetch(scopes = scope)
  googleCloudStorageR::gcs_auth(token = token)
  
  # Upload .csv and .pdf files to GCS
  filelist <- list.files(pattern = "\\.(csv|pdf)$")
  lapply(filelist, function(x) {
    googleCloudStorageR::gcs_upload(x, bucket = bucket, name = x)
    print(glue::glue("Uploaded file: {x}"))
  })
  
  print(glue::glue("All done. Check {bucket} for {pdf_name}"))

}
