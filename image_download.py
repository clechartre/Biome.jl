from better_bing_image_downloader import downloader

def main():
    downloader('cotton candy', limit=10, output_dir='/scratch/clechart/hackathon/data/train/', adult_filter_off=False,
    force_replace=False, timeout=60, filter="", verbose=True, badsites= [], name='cotton_candy')

if __name__ == "__main__":
    main()