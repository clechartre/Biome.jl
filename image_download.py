from better_bing_image_downloader import downloader

def main():
    downloader('stratus cloud', limit=1000, output_dir='/scratch/clechart/hackathon/data/train/', adult_filter_off=False,
    force_replace=False, timeout=100, filter="", verbose=True, badsites= [], name='Image')

if __name__ == "__main__":
    main()