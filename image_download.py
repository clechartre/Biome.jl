from better_bing_image_downloader import downloader

def main():
    downloader('cauliflower', limit=10, output_dir='/scratch/clechart/hackathon/data/train/', adult_filter_off=False,
    force_replace=False, timeout=60, filter="", verbose=True, badsites= [], name='cauliflower')

if __name__ == "__main__":
    main()