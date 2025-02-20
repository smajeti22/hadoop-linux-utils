import os
import subprocess
from multiprocessing import Pool

# Source file
SOURCE_FILE = "/etc/hosts"
# HDFS destination directory
HDFS_DEST = "hdfs:///tmp/distcp-dir/"
# Number of copies
NUM_COPIES = 2020
START = 1
END = 500
# Number of parallel threads
NUM_THREADS = 20

def upload_to_hdfs(file_index):
    """Uploads /etc/hosts to HDFS with a unique filename."""
    hdfs_path = f"{HDFS_DEST}hosts_{file_index}"
    command = f"hdfs dfs -put {SOURCE_FILE} {hdfs_path}"

    try:
        subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(f"Uploaded: hosts_{file_index}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to upload hosts_{file_index}: {e.stderr.decode()}")

if __name__ == "__main__":
    file_indices = list(range(START,END))

    # Create pool explicitly and close it properly
    pool = Pool(processes=NUM_THREADS)
    pool.map(upload_to_hdfs, file_indices)
    pool.close()
    pool.join()

    print("All files uploaded!")

