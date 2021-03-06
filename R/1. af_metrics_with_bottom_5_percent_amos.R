## Dashboard Model: F Assigned to Bottom 5%; A-D Grades Assigned to Metrics with AMOs

library(tidyverse)

school_accountability <- read_csv("data/school_accountability_file.csv")

hs <- school_accountability %>%
    filter(year == "2015", subject == "Success Rate", subgroup == "All Students", pool == "HS") %>%
    nrow()
k8 <- school_accountability %>%
    filter(year == "2015", subject == "Success Rate", subgroup == "All Students", pool == "K8") %>%
    nrow()

# Absenteeism Grade
absenteeism <- read_csv("data/absenteeism_indicator.csv") %>%
    select(system, school, subgroup, grade_absenteeism_absolute, grade_absenteeism_reduction)

# Students advancing in proficiency for subgroup growth
subgroup_growth <- read_csv("data/student_match_ranks.csv") %>%
    transmute(system, school,
        subgroup = ifelse(subgroup == "English Language Learners with T1/T2", "English Learners", subgroup),
        grade_growth = grade)

# ELPA
ELPA <- read_csv("data/elpa_indicator.csv") %>%
    select(system, school, subgroup, grade_exit, grade_growth_standard)

# F schools
F_schools <- school_accountability %>%
    filter(year == "3 Year", subject == "Success Rate", subgroup == "All Students") %>%
    mutate(TVAAS_sh = TVAAS_level %in% c("Level 4", "Level 5") & TVAAS_level_lag %in% c("Level 4", "Level 5")) %>%
    group_by(pool, designation_ineligible, TVAAS_sh) %>%
    mutate(rank = rank(pct_prof_adv, ties.method = "min")) %>%
    ungroup() %>%
    transmute(system, system_name, school, school_name,
        final_grade = ifelse(rank <= ceiling(0.05 * hs) & pool == "HS" & !designation_ineligible & !TVAAS_sh, "F", NA),
        final_grade = ifelse(rank <= ceiling(0.05 * k8) & pool == "K8" & !designation_ineligible & !TVAAS_sh, "F", final_grade))

# ACT and Grad
ACT <- school_accountability %>%
    filter(subject == "ACT Composite") %>%
    select(system, school, subgroup, valid_tests_ACT = valid_tests, pct_21_ACT = pct_prof_adv,
        valid_tests_prior_ACT = valid_tests_prior, pct_21_prior_ACT = pct_prof_adv_prior)

ACT_grad <- school_accountability %>%
    filter(subject == "Graduation Rate") %>%
    select(system, school, subgroup, grad_cohort = valid_tests, grad_rate = pct_prof_adv,
        grad_cohort_prior = valid_tests_prior, grad_rate_prior = pct_prof_adv_prior) %>%
    full_join(ACT, by = c("system", "school", "subgroup")) %>%
    mutate(ACT_grad_prior = ifelse(valid_tests_prior_ACT >= 30 & grad_cohort_prior >= 30,
            round(grad_rate_prior * pct_21_prior_ACT/100, 1), NA),
        AMO_target = round(ACT_grad_prior + (100 - ACT_grad_prior)/16, 1),
        AMO_target_4 = round(ACT_grad_prior + (100 - ACT_grad_prior)/8, 1),
        ACT_grad = ifelse(valid_tests_ACT >= 30 & grad_cohort >= 30, round(grad_rate * pct_21_ACT/100, 1), NA),
        grade_readiness_absolute = ifelse(ACT_grad <= 16, "F", NA),
        grade_readiness_absolute = ifelse(ACT_grad > 16, "D", grade_readiness_absolute),
        grade_readiness_absolute = ifelse(ACT_grad > 28, "C", grade_readiness_absolute),
        grade_readiness_absolute = ifelse(ACT_grad > 35, "B", grade_readiness_absolute),
        grade_readiness_absolute = ifelse(ACT_grad >= 50, "A", grade_readiness_absolute),
        grade_readiness_target = ifelse(ACT_grad < ACT_grad_prior, "F", NA),
        grade_readiness_target = ifelse(ACT_grad == ACT_grad_prior, "D", grade_readiness_target),
        grade_readiness_target = ifelse(ACT_grad > ACT_grad_prior, "C", grade_readiness_target),
        grade_readiness_target = ifelse(ACT_grad >= AMO_target, "B", grade_readiness_target),
        grade_readiness_target = ifelse(ACT_grad >= AMO_target_4, "A", grade_readiness_target))

# Achievement and growth
ach_growth <- school_accountability %>%
    filter(year == "2015", subject == "Success Rate") %>%
    mutate(grade_relative_achievement = ifelse(pctile_rank_PA <= 20, "F", NA),
        grade_relative_achievement = ifelse(pctile_rank_PA > 20, "D", grade_relative_achievement),
        grade_relative_achievement = ifelse(pctile_rank_PA > 40, "C", grade_relative_achievement),
        grade_relative_achievement = ifelse(pctile_rank_PA > 60, "B", grade_relative_achievement),
        grade_relative_achievement = ifelse(pctile_rank_PA > 80, "A", grade_relative_achievement),
        grade_achievement_AMO = ifelse(upper_bound_ci_PA <= pct_prof_adv_prior, "F", NA),
        grade_achievement_AMO = ifelse(upper_bound_ci_PA > pct_prof_adv_prior, "D", grade_achievement_AMO),
        grade_achievement_AMO = ifelse(upper_bound_ci_PA >= AMO_target_PA, "C", grade_achievement_AMO),
        grade_achievement_AMO = ifelse(pct_prof_adv > AMO_target_PA, "B", grade_achievement_AMO),
        grade_achievement_AMO = ifelse(pct_prof_adv >= AMO_target_PA_4, "A", grade_achievement_AMO),
        grade_achievement_AMO = ifelse(valid_tests < 30, NA, grade_achievement_AMO),
        grade_TVAAS = ifelse(TVAAS_level == "Level 5", "A", NA),
        grade_TVAAS = ifelse(TVAAS_level == "Level 4", "B", grade_TVAAS),
        grade_TVAAS = ifelse(TVAAS_level == "Level 3", "C", grade_TVAAS),
        grade_TVAAS = ifelse(TVAAS_level == "Level 2", "D", grade_TVAAS),
        grade_TVAAS = ifelse(TVAAS_level == "Level 1", "F", grade_TVAAS)) %>%
    left_join(subgroup_growth, by = c("system", "school", "subgroup")) %>%
    select(system, system_name, school, school_name, subgroup, pool, designation_ineligible,
        grade_relative_achievement, grade_achievement_AMO, grade_TVAAS, grade_growth)

# Full Heat Map
AF_grades_metrics <- ach_growth %>%
    left_join(ACT_grad, by = c("system", "school", "subgroup")) %>%
    left_join(absenteeism, by = c("system", "school", "subgroup")) %>%
    left_join(ELPA, by = c("system", "school", "subgroup")) %>%
    transmute(system, system_name, school, school_name, subgroup, pool, designation_ineligible,
        priority_grad = ifelse(subgroup == "All Students", !designation_ineligible & grad_cohort >= 30 & grad_rate < 67, NA),
    # Not setting na.rm = TRUE for pmin so that only schools with both absolute and AMO receive a grade
        grade_achievement = pmin(grade_relative_achievement, grade_achievement_AMO),
        grade_growth = ifelse(subgroup == "All Students", grade_TVAAS, grade_growth),
        grade_readiness = pmin(grade_readiness_absolute, grade_readiness_target),
        grade_absenteeism = pmin(grade_absenteeism_absolute, grade_absenteeism_reduction),
        grade_ELPA = pmin(grade_exit, grade_growth_standard)) %>%
    mutate_at(vars(starts_with("grade_")), funs(recode(., "A" = 4, "B" = 3, "C" = 2, "D" = 1, "F" = 0))) %>%
# Weights
    mutate(weight_achievement = ifelse(!is.na(grade_achievement) & pool == "K8", 0.45, NA),
        weight_achievement = ifelse(!is.na(grade_achievement) & pool == "HS", 0.3, weight_achievement),
        weight_growth = ifelse(!is.na(grade_growth) & pool == "K8", 0.35, NA),
        weight_growth = ifelse(!is.na(grade_growth) & pool == "HS", 0.25, weight_growth),
        weight_readiness = ifelse(!is.na(grade_readiness) & pool == "HS", 0.25, NA),
        weight_opportunity = ifelse(!is.na(grade_absenteeism), 0.1, NA),
        weight_ELPA = ifelse(!is.na(grade_ELPA), 0.1, NA),
    # If no ELPA, adjust achievement and growth weights accordingly
        weight_achievement = ifelse(is.na(grade_ELPA) & !is.na(grade_achievement) & pool == "K8", 0.5, weight_achievement),
        weight_achievement = ifelse(is.na(grade_ELPA) & !is.na(grade_achievement) & pool == "HS", 0.35, weight_achievement),
        weight_growth = ifelse(is.na(grade_ELPA) & !is.na(weight_growth) & pool == "K8", 0.4, weight_growth),
        weight_growth = ifelse(is.na(grade_ELPA) & !is.na(weight_growth) & pool == "HS", 0.3, weight_growth)) %>%
    rowwise() %>%
    mutate(total_weight = sum(weight_achievement, weight_growth, weight_opportunity, weight_readiness, weight_ELPA, na.rm = TRUE),
        subgroup_average = sum(weight_achievement * grade_achievement,
            weight_growth * grade_growth,
            weight_opportunity * grade_absenteeism,
            weight_readiness * grade_readiness,
            weight_ELPA * grade_ELPA, na.rm = TRUE)/total_weight) %>%
    ungroup()

# Achievement grades
all_students_grades_final <- AF_grades_metrics %>%
    filter(subgroup == "All Students") %>%
    transmute(system, system_name, school, school_name, pool, designation_ineligible, priority_grad,
        achievement_average = subgroup_average,
        achievement_grade = ifelse(achievement_average == 0, "F", NA),
        achievement_grade = ifelse(achievement_average > 0, "D", achievement_grade),
        achievement_grade = ifelse(achievement_average > 1, "C", achievement_grade),
        achievement_grade = ifelse(achievement_average > 2, "B", achievement_grade),
        achievement_grade = ifelse(achievement_average > 3, "A", achievement_grade))

# Targeted support schools
targeted_support <- AF_grades_metrics %>%
    filter(subgroup %in% c("Black/Hispanic/Native American", "Economically Disadvantaged",
        "English Learners", "Students with Disabilities")) %>%
    select(system, school, subgroup, designation_ineligible, subgroup_average) %>%
    full_join(F_schools, by = c("system", "school")) %>%
    group_by(subgroup) %>%
    mutate(denom = sum(!is.na(subgroup_average))) %>%
    group_by(subgroup, designation_ineligible, final_grade) %>%
    mutate(rank = rank(subgroup_average, ties.method = "min"),
        targeted_support = ifelse(is.na(final_grade) & !designation_ineligible, rank <= ceiling(0.05 * denom), NA)) %>%
    ungroup() %>%
    select(system, school, subgroup, final_grade, targeted_support) %>%
    spread(subgroup, targeted_support) %>%
    transmute(system, school,
        targeted_support_BHN = `Black/Hispanic/Native American`,
        targeted_support_ED = `Economically Disadvantaged`,
        targeted_support_SWD = `Students with Disabilities`,
        targeted_support_EL = `English Learners`,
        targeted_support = ifelse(is.na(final_grade), 
            pmax(targeted_support_BHN, targeted_support_ED, targeted_support_SWD, targeted_support_EL, na.rm = TRUE), NA))

# Gap closure grades
subgroup_grades_final <- AF_grades_metrics %>%
    filter(subgroup != "All Students") %>%
# Drop Super Subgroup observation if other subgroups are present
    mutate(temp = !is.na(subgroup_average)) %>%
    group_by(system, system_name, school, school_name) %>%
    mutate(subgroups_count = sum(temp)) %>%
    filter(!(subgroup == "Super Subgroup" & subgroups_count > 1)) %>%
# Weight by total weight of the indicators represented by each subgroup
    mutate(subgroup_average_weighted = total_weight * subgroup_average) %>%
    summarise_each(funs(sum(., na.rm = TRUE)), total_weight, subgroup_average_weighted) %>%
    ungroup() %>%
    transmute(system, system_name, school, school_name, 
        gap_closure_average = subgroup_average_weighted/total_weight,
        gap_closure_grade = ifelse(gap_closure_average == 0, "F", NA),
        gap_closure_grade = ifelse(gap_closure_average > 0, "D", gap_closure_grade),
        gap_closure_grade = ifelse(gap_closure_average > 1, "C", gap_closure_grade),
        gap_closure_grade = ifelse(gap_closure_average > 2, "B", gap_closure_grade),
        gap_closure_grade = ifelse(gap_closure_average > 3, "A", gap_closure_grade))

AF_grades_final <- all_students_grades_final %>%
    full_join(subgroup_grades_final, by = c("system", "system_name", "school", "school_name")) %>%
    full_join(F_schools, by = c("system", "system_name", "school", "school_name")) %>%
    full_join(targeted_support, by = c("system", "school")) %>%
    mutate(final_grade = ifelse(is.na(final_grade) & priority_grad, "F", final_grade),
        overall_average = round(0.6 * achievement_average + 0.4 * gap_closure_average, 1),
        overall_average = ifelse(is.na(overall_average), achievement_average, overall_average),
        final_grade = ifelse(is.na(final_grade) & overall_average <= 1, "D", final_grade),
        final_grade = ifelse(is.na(final_grade) & overall_average > 1 & overall_average <= 2, "C", final_grade),
        final_grade = ifelse(is.na(final_grade) & overall_average > 2 & overall_average <= 3, "B", final_grade),
        final_grade = ifelse(is.na(final_grade) & overall_average > 3, "A", final_grade),
        final_grade = ifelse(designation_ineligible, NA, final_grade),
        # targeted_support = ifelse(final_grade == "D", 1, targeted_support),
        targeted_support = ifelse(designation_ineligible, NA, targeted_support),
        priority_grad = ifelse(is.na(priority_grad), FALSE, priority_grad),
        targeted_support = ifelse(priority_grad, NA, targeted_support),
        targeted_support = ifelse(is.na(targeted_support), FALSE, targeted_support)) %>%
    select(system, system_name, school, school_name, pool, designation_ineligible, priority_grad,
        achievement_average, achievement_grade, gap_closure_average, gap_closure_grade, overall_average,
        contains("targeted_support"), final_grade)

# Output files
write_csv(AF_grades_metrics, path = paste0("output/AF_bottom_five_amos_metrics.csv"), na = "")
write_csv(AF_grades_final, path = paste0("output/AF_bottom_five_amos_final_grades.csv"), na = "")

