import os
from zipfile import ZipFile

INPUT_DIR = r"C:\Users\lkise\OneDrive\LAM\CHAT-GPT\CHATS_UNARCHIVED"
OUTPUT_DIR = r"C:\Users\lkise\OneDrive\LAM\CHAT-GPT\CHATS_ARCHIVED"
MAX_ARCHIVE_SIZE_MB = 25

def zip_chats():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    archive_num = 1
    current_archive_size = 0
    current_archive_files = []

    for root, dirs, files in os.walk(INPUT_DIR):
        for file in files:
            file_path = os.path.join(root, file)
            file_size = os.path.getsize(file_path) / (1024 * 1024)  # size in MB

            if current_archive_size + file_size > MAX_ARCHIVE_SIZE_MB and current_archive_files:
                archive_name = os.path.join(OUTPUT_DIR, f"archive_{archive_num:03}.zip")
                with ZipFile(archive_name, 'w') as archive:
                    for f in current_archive_files:
                        archive.write(f, os.path.relpath(f, INPUT_DIR))
                print(f"✅ Архив {archive_name} создан.")
                
                archive_num += 1
                current_archive_files = []
                current_archive_size = 0

            current_archive_files.append(file_path)
            current_archive_size += file_size

    # Create archive from remaining files
    if current_archive_files:
        archive_name = os.path.join(OUTPUT_DIR, f"archive_{archive_num:03}.zip")
        with ZipFile(archive_name, 'w') as archive:
            for f in current_archive_files:
                archive.write(f, os.path.relpath(f, INPUT_DIR))
        print(f"✅ Архив {archive_name} создан.")

if __name__ == "__main__":
    zip_chats()
