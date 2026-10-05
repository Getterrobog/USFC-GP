#!/usr/bin/env python3

Usage = """
Coding: utf-8, end of line character is \n, one indent is 4 spaces
Created on Thu Aug 20 19:54:45 2026
Script purpose: Iterates through a text file of species names, submits each to 
Eschmeyer's Catalog of Fishes via MechanicalSoup, extracts the valid binomial, 
and writes the output to a CSV file.
Version 1.1
@author: Iván Raúl López Martínez, ivan.r.lopez@hotmail.com
Script Name: species_checkinator.py
"""

import os, sys, time, csv, re, mechanicalsoup

def process_species_list(input_file_path, output_csv_path):
    # Enforce pure-python html.parser to avoid lxml C-extension initialization issues
    browser = mechanicalsoup.StatefulBrowser(
        soup_config={'features': 'html.parser'},
        user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    )
    url = "https://researcharchive.calacademy.org/research/ichthyology/catalog/fishcatmain.asp"

    # Standardized extraction patterns
    valid_as_pattern = re.compile(r'Current status:\s*Valid as\s+([A-Z][a-z]+\s+[a-z]+)', re.IGNORECASE)
    synonym_of_pattern = re.compile(r'Current status:\s*Synonym of\s+([A-Z][a-z]+\s+[a-z]+)', re.IGNORECASE)
    uncertain_pattern = re.compile(r'Current status:\s*Uncertain', re.IGNORECASE)
    
    if not os.path.exists(input_file_path):
        sys.stderr.write(f"Error: Input file '{input_file_path}' not found.\n")
        sys.exit(1)

    with open(input_file_path, 'r', encoding='utf-8') as infile:
        species_list = [line.strip() for line in infile if line.strip() and not line.startswith("Identification")]

    print(f"Loaded {len(species_list)} species from {input_file_path}. Processing queries...")

    with open(output_csv_path, 'w', newline='', encoding='utf-8') as outfile:
        writer = csv.writer(outfile)
        writer.writerow(['Input_Name', 'Valid_Name'])

        for idx, species in enumerate(species_list, 1):
            valid_name = "Human search"
            try:
                parts = species.split()
                if len(parts) >= 2:
                    genus_input, species_input = parts[0], parts[1]
                    target_heading_prefix = f"{species_input}, {genus_input}".lower()
                else:
                    genus_input, species_input = species, ""
                    target_heading_prefix = species.lower()

                # Submit query
                browser.open(url)
                browser.select_form()
                browser["contains"] = species
                browser.submit_selected()

                # Use built-in BeautifulSoup object directly from MechanicalSoup
                soup = browser.page

                results = soup.find_all('p', class_='result')

                if results:
                    # CONDITION 1: Match paragraph heading to target species & check "Valid as"
                    for p in results:
                        p_text = " ".join(p.get_text().split())
                        if p_text.lower().startswith(target_heading_prefix):
                            match_valid = valid_as_pattern.search(p_text)
                            if match_valid:
                                valid_name = match_valid.group(1).strip()
                                break

                    # CONDITION 2: Match paragraph heading to target species & check "Synonym of"
                    if valid_name == "Human search":
                        for p in results:
                            p_text = " ".join(p.get_text().split())
                            if p_text.lower().startswith(target_heading_prefix):
                                match_syn = synonym_of_pattern.search(p_text)
                                if match_syn:
                                    valid_name = match_syn.group(1).strip()
                                    break

                    # CONDITION 3: Single-result entry marked as "Uncertain"
                    if valid_name == "Human search":
                        spid_results = soup.find_all('p', spid=True)
                        if len(spid_results) == 1:
                            p_text = " ".join(spid_results[0].get_text().split())
                            if uncertain_pattern.search(p_text):
                                valid_name = "Uncertain"

                    # CONDITION 4: Reassigned combination match
                    if valid_name == "Human search" and species_input:
                        for p in results:
                            p_text = " ".join(p.get_text().split())
                            if p_text.lower().startswith(f"{species_input.lower()},"):
                                if species.lower() in p_text.lower():
                                    match_valid = valid_as_pattern.search(p_text)
                                    if match_valid:
                                        valid_name = match_valid.group(1).strip()
                                        break
                                    match_syn = synonym_of_pattern.search(p_text)
                                    if match_syn:
                                        valid_name = match_syn.group(1).strip()
                                        break

                    # Last CONDITION: Global fallback for records without strict heading matches
                    if valid_name == "Human search":
                        full_text = " ".join([" ".join(p.get_text().split()) for p in results])
                        match_valid_global = valid_as_pattern.search(full_text)
                        if match_valid_global:
                            valid_name = match_valid_global.group(1).strip()

                writer.writerow([species, valid_name])
                print(f"[{idx}/{len(species_list)}] {species} -> {valid_name}")

                time.sleep(0.4)

            except Exception as e:
                sys.stderr.write(f"Error processing '{species}': {e}\n")
                writer.writerow([species, "Human search"])

    print(f"\nProcessing complete. Output saved to: {output_csv_path}")
if __name__ == "__main__":
    input_path = sys.argv[1] if len(sys.argv) > 1 else "species_list.txt"
    output_path = "species_validation_results.csv"
    process_species_list(input_path, output_path)