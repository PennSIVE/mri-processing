# 
# Neuroimaging pre-processing and visualization 
# Kelly Clark & Melissa Martin
#
# 

library(neurobase)
library(oro.dicom)
library(oro.nifti)
library(ANTsR)
library(extrantsr)
library(WhiteStripe)
library(fslr)
library(RJSONIO)

baselineDCMSource <- "/baseline"
followupDCMSource <- "/followup"
processed_dir_path <- "/processed"
ws_type <- Sys.getenv("WS_TYPE")
stopifnot(ws_type == "T1" || ws_type == "T2")

#read in DICOM series 
print(paste0("Now reading in dicom images"))
baseline_img <<- readDICOM(baselineDCMSource)
followup_img <<- readDICOM(followupDCMSource)


##convert dicom to nifti and write nifti to file
print(paste0("Dicom images have been read in and are now being converted to NIFTI images"))
baseline_nifti <<- dicom2nifti(baseline_img)
followup_nifti <<- dicom2nifti(followup_img)
#writenii(baseline_nifti, paste0(processed_dir_path,"/Baseline.nii.gz"))
#writenii(followup_nifti, paste0(processed_dir_path,"/FollowUp.nii.gz"))

#ANTS N4 correction
print(paste0("Now N4 correcting nifti images"))
baseline_n4 <<- bias_correct(baseline_nifti, correction = "N4")
followup_n4 <<- bias_correct(followup_nifti, correction = "N4")
#writenii(baseline_n4, paste0(processed_dir_path,"/Baseline_N4.nii.gz"))
writenii(followup_n4, paste0(processed_dir_path, "/FollowUp_N4.nii.gz"))

#ANTS registration of FollowUp to Baseline
# print(paste0("Now registering baseline image to follow-up image"))
baseline_to_followup <<- antsRegistration(fixed = oro2ants(followup_n4), moving = oro2ants(baseline_n4),
                                        typeofTransform = c("Rigid"))
baseline_reg <<- antsApplyTransforms(fixed = oro2ants(followup_n4), moving = oro2ants(baseline_n4),
                                  transformlist = baseline_to_followup$fwdtransforms,
                                  interpolator = c("WelchWindowedSinc"))
baseline_reg_path <<- paste0(processed_dir_path, "/baselineN4_to_followupN4_reg.nii.gz")
antsImageWrite(baseline_reg, baseline_reg_path)

# new stuff

baseline_fast <<- fast(baseline_reg,
                       outfile = paste0(processed_dir_path, "/baseline"),
                       bias_correct = FALSE)
baseline_CSF_mask <<- readnii(paste0(processed_dir_path, "/baseline_pve_0.nii.gz")) > 0
baseline_GM_mask <<- readnii(paste0(processed_dir_path, "/baseline_pve_1.nii.gz")) > 0
baseline_WM_mask <<- readnii(paste0(processed_dir_path, "/baseline_pve_2.nii.gz")) > 0
baseline_CSF = (table(baseline_CSF_mask[baseline_CSF_mask != 0]))
baseline_GM = (table(baseline_GM_mask[baseline_GM_mask != 0]))
baseline_WM = (table(baseline_WM_mask[baseline_WM_mask != 0]))
baseline_vols = rbind(baseline_CSF, baseline_GM, baseline_WM)
vres = voxres(baseline_reg, units = "cm")
baseline_vols = baseline_vols * vres
# colnames(baseline_vols) = c("CSF","GM","WM")
# rownames(baesline_vols) = "Baseline"
followup_fast <<- fast(followup_n4,
                         outfile = paste0(processed_dir_path, "/followup"),
                         bias_correct = FALSE)
followup_CSF_mask <<- readnii(paste0(processed_dir_path, "/followup_pve_0.nii.gz")) > 0
followup_GM_mask <<- readnii(paste0(processed_dir_path, "/followup_pve_1.nii.gz")) > 0
followup_WM_mask <<- readnii(paste0(processed_dir_path, "/followup_pve_2.nii.gz")) > 0
followup_CSF = (table(followup_CSF_mask[followup_CSF_mask != 0]))
followup_GM = (table(followup_GM_mask[followup_GM_mask != 0]))
followup_WM = (table(followup_WM_mask[followup_WM_mask != 0]))
followup_vols = rbind(followup_CSF, followup_GM, followup_WM)
vres = voxres(followup_n4, units = "cm")
followup_vols = followup_vols * vres
# colnames(followup_vols) = c("CSF","GM","WM")
# rownames(followup_vols) = "Followup"
base_and_followup_vols = rbind(baseline_vols, followup_vols)
write(toJSON(base_and_followup_vols), paste0(processed_dir_path, "/tissue_class_volumes.json"))
# write.csv(base_and_followup_vols,(paste0(processed_dir_path,"/tissue_class_volumes.csv")))


#FSL FIRST 
system(paste("run_first_all -b -s R_Thal,L_Thal -i", paste0(processed_dir_path, "/baselineN4_to_followupN4_reg.nii.gz"), "-o", paste0(processed_dir_path, "/baseline_thalamus")))
system(paste("run_first_all -b -s R_Thal,L_Thal -i", paste0(processed_dir_path, "/FollowUp_N4.nii.gz"), "-o", paste0(processed_dir_path, "/followup_thalamus")))
baseline_thal = readnii(paste0(processed_dir_path, "/baseline_thalamus_all_none_firstseg.nii.gz"))
thal_lab_1 = (table(baseline_thal[baseline_thal == 10]))
thal_lab_2 = (table(baseline_thal[baseline_thal == 49]))
vres = voxres(baseline_reg, units = "cm")
baseline_thal_vol = (vres * thal_lab_1) + (vres * thal_lab_2)
# colnames(baseline_thal_vol)="Baseline"
followup_thal = readnii(paste0(processed_dir_path, "/followup_thalamus_all_none_firstseg.nii.gz"))
thal_lab_1 = (table(followup_thal[followup_thal == 10]))
thal_lab_2 = (table(followup_thal[followup_thal == 49]))
vres = voxres(followup_n4, units = "cm")
followup_thal_vol = (vres * thal_lab_1) + (vres * thal_lab_2)
# colnames(baseline_thal_vol)="Followup"
base_and_followup_thal = cbind(baseline_thal_vol, followup_thal_vol)
# colnames(base_and_followup_thal) = c("Baseline","Followup")
# rownames(base_and_followup_thal)="Thalamic Volume"
# write.csv(base_and_followup_thal,(paste0(processed_dir_path,"/thalamic_volumes.csv")))
write(toJSON(base_and_followup_thal), paste0(processed_dir_path, "/thalamic_volumes.json"))

# end new stuff

#WhiteStripe
print(paste0("Finished registration, now performing WhiteStripe normalization"))
baseline_ind <<- whitestripe(ants2oro(baseline_reg), ws_type)
baseline_ws <<- whitestripe_norm(ants2oro(baseline_reg), baseline_ind$whitestripe.ind)
#writenii(baseline_ws, paste0(processed_dir_path,"/Baseline_WS.nii.gz"))

followup_ind <<- whitestripe(followup_n4, ws_type)
followup_ws <<- whitestripe_norm(followup_n4, followup_ind$whitestripe.ind)
#writenii(followup_ws, paste0(processed_dir_path,"/Followup_WS.nii.gz"))
difference <<- (followup_ws - baseline_ws)
writenii(difference, paste0(processed_dir_path, "/difference_WS.nii.gz"))
print(paste0("Finished WhiteStripe normalization, opening image in ITK-SNAP"))
