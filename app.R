# 
# Neuroimaging pre-processing and visualization 
# Kelly Clark & Melissa Martin
#
# 

# note: order of imported libraries matters
# "You have loaded oro.nifti after extrantsr (either directly or from another package) - this is likely to cause problems with certain functions on antsImage types, such as origin.
# if you need functions from both extrantsr and oro.nifti, please load oro.nifti first, then extrantsr"
library(shiny)
library(neurobase)
library(oro.dicom)
library(oro.nifti)
library(ANTsR)
library(extrantsr)
library(shinyFiles)
library(shinyWidgets)
library(WhiteStripe)
library(itksnapr)

 itksnap <- function(
   grayscale, # filenames or nifti objects to be displayed.  
   overlay = NULL,
   segmentation = NULL, # segmentation image using \code{-s} option
   labels = NULL, # label descriptions using \code{-s} option
   zoom = NULL, # initial zoom in screen pixels/mm
   verbose = TRUE, # Print out the command executed
   ... # arguments to pass to \code{\link{itksnap_cmd}}
 ){
   install_itksnap()
   maker = function(x){
     if (is.nifti(x)) {
       x = checkimg(x)
     }
     x = sapply(x, checkimg)
   }
   
   ################
   # Force to names
   ################
   grayscale = maker(grayscale)
   names(grayscale) = rep("-g", length(grayscale))
   
   maker2 = function(vec, lab){
     if (length(vec) > 0){
       vec = maker(vec)
       names(vec)[1] = lab
       names(vec)[2:length(vec)] = ""
     }    
     return(vec)
   }
   
   overlay = maker2(overlay, "-o")
   segmentation = maker2(segmentation, "-s")
   labels = maker2(labels, "-l")
   
   if (length(zoom) > 0){
     names(zoom) = "-z"
   }
   
   allfiles = c(grayscale, overlay, segmentation, labels, zoom)
   file.names = names(allfiles)
   allfiles = normalizePath(allfiles)
   allfiles = shQuote(allfiles)
   cmd = paste(file.names, 
               allfiles, 
               collapse = " ")
   cmd = sprintf('%s %s', shQuote(itksnap_cmd(...)), cmd)
   if (verbose){
     cat(paste0(cmd, "\n"))
   }
   res = system(cmd, ignore.stderr = TRUE, ignore.stdout = TRUE)
   return(res)
 }


# Define UI for application
ui <- fluidPage( 
  titlePanel(
    h1("Image Processing App", align = "center")),
  tags$head(tags$style('body{color:black;')),
  setBackgroundColor(color = "AliceBlue"),            
  
  fluidRow(
    column(width = 12,
           
           h4("Baseline"),        
           #creates finder-like gui to select dicom folder 
           shinyDirButton("button1", "Choose directory:",
                          "Choose baseline directory"),    
           #prints which directory you chose on-screen   
           verbatimTextOutput("message1"),             
           
           h4("Follow-up"),
           shinyDirButton("button2", "Choose directory:"
                          ,"Choose follow-up directory"),    
           verbatimTextOutput("message2"),
          
           #radio buttons containing image type chooses/selection is used in WhiteStripe normalization
           prettyRadioButtons("type","Please select an image type:",
                              bigger = TRUE, fill = TRUE, 
                              choices = c("T1"="T1","T2"="T2"), 
                              selected =character(0)),
           verbatimTextOutput("message3"), 
           
           #Selection of button commences pre-processing steps
           actionButton("go","GO"),
           

           #Selection of button opens specified image in ITK-SNAP
           actionButton("itk","View images in ITK-SNAP"),  
           
          
           
    )
  )
  
)  

server <- function(input, output,session) {
  
  #pulls all available volumes on the OS that the app is running on icluding flash drive
  volumes =getVolumes()
  
  #creates a gui that looks like Windows Explorer containing all volumes in current OS
  shinyDirChoose(input, "button1", roots = volumes, session =session )
  
  shinyDirChoose(input, "button2", roots = volumes, session =session )
  
  
  baselineDCM <-observeEvent(input$button1,{   #reactive event begins when baselinefileInput selected
    baselineDCMSource<<-parseDirPath(volumes, input$button1) #baseline dicom source = whatever was selected
    output$message1<-renderPrint({               #prints file path that was selected
      baselineDCMSource
    })     
  })
  
  followupDCM<-observeEvent(input$button2,{
    followupDCMSource<<- parseDirPath(volumes, input$button2)    
    output$message2<-renderPrint({
      followupDCMSource
    })
  })
  

  WS_types<-observeEvent(input$type,{
    ws_type<<-input$type
    output$message3<-renderPrint({
      paste("You chose",ws_type)
  })
  })

   Processing = observeEvent(input$go,{ 
    #created processed folder within followup dir
    followup_dir = paste0(followupDCMSource)  
    processed_dir = "Processed" 
    Processed_dir_path = file.path(followup_dir, processed_dir)
    dir.create(Processed_dir_path)
   
    #read in DICOM series 
    showModal(modalDialog("Now reading in dicom images"))
    baseline_img <<- readDICOM(baselineDCMSource)
    followup_img <<- readDICOM(followupDCMSource)
    
    
    ##convert dicom to nifti and write nifti to file
    showModal(modalDialog("Dicom images have been read in and are now being converted to NIFTI images"))
    baseline_nifti <<- dicom2nifti(baseline_img)
    followup_nifti <<- dicom2nifti(followup_img)
    #writenii(baseline_nifti, paste0(Processed_dir_path,"/Baseline.nii.gz"))
    #writenii(followup_nifti, paste0(Processed_dir_path,"/FollowUp.nii.gz"))
    
    #ANTS N4 correction
    showModal(modalDialog("Now N4 correcting nifti images"))
    baseline_n4<<- bias_correct(baseline_nifti, correction = "N4")
    followup_n4<<- bias_correct(followup_nifti, correction = "N4")
    #writenii(baseline_n4, paste0(Processed_dir_path,"/Baseline_N4.nii.gz"))
    writenii(followup_n4, paste0(Processed_dir_path,"/FollowUp_N4.nii.gz"))
    
    #ANTS registration of FollowUp to Baseline
    showModal(modalDialog("Now registering baseline image to follow-up image"))
    baseline_to_followup<<- antsRegistration(fixed=oro2ants(followup_n4), moving=oro2ants(baseline_n4), 
                                             typeofTransform=c("Rigid"))
    baseline_reg<<- antsApplyTransforms(fixed=oro2ants(followup_n4), moving=oro2ants(baseline_n4),
                                        transformlist = baseline_to_followup$fwdtransforms,
                                        interpolator =c("WelchWindowedSinc"))
    antsImageWrite(baseline_reg, paste0(Processed_dir_path,"/baselineN4_to_followupN4_reg.nii.gz"))
    
    #WhiteStripe
    showModal(modalDialog("Finished registration, now performing WhiteStripe normalization"))
      baseline_ind<<- whitestripe(ants2oro(baseline_reg), ws_type)
      baseline_ws<<- whitestripe_norm(ants2oro(baseline_reg), baseline_ind$whitestripe.ind)
      #writenii(baseline_ws, paste0(Processed_dir_path,"/Baseline_WS.nii.gz"))
        
      followup_ind<<-whitestripe(followup_n4, ws_type)
      followup_ws<<-whitestripe_norm(followup_n4, followup_ind$whitestripe.ind)
      #writenii(followup_ws, paste0(Processed_dir_path,"/Followup_WS.nii.gz"))
      difference<<- (followup_ws - baseline_ws)
      writenii(difference, paste0(Processed_dir_path,"/difference_WS.nii.gz"))
      showModal(modalDialog("Finished WhiteStripe normalization, opening image in ITK-SNAP"))
      
      
      itksnap(paste0(Processed_dir_path,"/difference_WS.nii.gz"), 
              c(paste0(Processed_dir_path,"/baselineN4_to_followupN4_reg.nii.gz"),
              paste0(Processed_dir_path,"/FollowUp_N4.nii.gz")))
      
      ImageViewer<-observeEvent(input$itk,{
        itksnap(paste0(Processed_dir_path,"/difference_WS.nii.gz"), 
                c(paste0(Processed_dir_path,"/baselineN4_to_followupN4_reg.nii.gz"),
                paste0(Processed_dir_path,"/FollowUp_N4.nii.gz")))
        
         })
     })
}

# Run the application 
shinyApp(ui = ui, server = server)


#### ~5.5 minute run time if running on Desktop and imgs are local


