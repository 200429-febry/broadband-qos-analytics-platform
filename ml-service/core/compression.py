import numpy as np
from scipy import fftpack

def compute_entropy(data: np.ndarray) -> float:
    """
    Menghitung entropi Shannon dari sekumpulan data (misal array piksel atau sinyal).
    Diperlukan untuk analisis efisiensi kompresi.
    """
    _, counts = np.unique(data, return_counts=True)
    probabilities = counts / counts.sum()
    entropy = -np.sum(probabilities * np.log2(probabilities))
    return entropy

def dct_2d_from_scratch(block: np.ndarray) -> np.ndarray:
    """
    Implementasi manual Discrete Cosine Transform (DCT) 2D untuk blok gambar 8x8.
    Ditulis dari awal menggunakan numpy untuk menunjukkan transparansi algoritma.
    """
    N = block.shape[0]
    out = np.zeros((N, N))
    for u in range(N):
        for v in range(N):
            su = 1 / np.sqrt(2) if u == 0 else 1
            sv = 1 / np.sqrt(2) if v == 0 else 1
            
            sum_val = 0
            for x in range(N):
                for y in range(N):
                    sum_val += block[x, y] * \
                               np.cos((2 * x + 1) * u * np.pi / (2 * N)) * \
                               np.cos((2 * y + 1) * v * np.pi / (2 * N))
            out[u, v] = 0.25 * su * sv * sum_val
    return out

def motion_vector_estimation(ref_frame: np.ndarray, curr_frame: np.ndarray, block_size: int = 8, search_area: int = 16) -> tuple:
    """
    Implementasi prediksi vektor gerak (Motion Estimation) menggunakan algoritma Exhaustive Search.
    Untuk menganalisis redundancy temporal pada streaming video.
    """
    h, w = ref_frame.shape
    motion_vectors = []
    
    for y in range(0, h - block_size + 1, block_size):
        for x in range(0, w - block_size + 1, block_size):
            curr_block = curr_frame[y:y+block_size, x:x+block_size]
            
            # Area pencarian
            min_y = max(0, y - search_area)
            max_y = min(h - block_size, y + search_area)
            min_x = max(0, x - search_area)
            max_x = min(w - block_size, x + search_area)
            
            best_mad = float('inf')
            best_dy, best_dx = 0, 0
            
            for sy in range(min_y, max_y + 1):
                for sx in range(min_x, max_x + 1):
                    ref_block = ref_frame[sy:sy+block_size, sx:sx+block_size]
                    mad = np.sum(np.abs(curr_block - ref_block)) / (block_size * block_size)  # Mean Absolute Difference
                    
                    if mad < best_mad:
                        best_mad = mad
                        best_dy = sy - y
                        best_dx = sx - x
                        
            motion_vectors.append(((y, x), (best_dy, best_dx)))
            
    return motion_vectors

def analyze_qos_compression(frame1: np.ndarray, frame2: np.ndarray):
    """
    Analisis QoS berdasarkan estimasi bitrate setelah kompresi teoretis.
    """
    entropy_raw = compute_entropy(frame2)
    # Gunakan DCT pada skala makro (contoh implementasi konsep)
    sample_block = frame2[0:8, 0:8] if frame2.shape[0] >= 8 and frame2.shape[1] >= 8 else np.zeros((8,8))
    dct_block = dct_2d_from_scratch(sample_block)
    
    # Kuantisasi sederhana
    quantized_dct = np.round(dct_block / 10.0)
    entropy_compressed = compute_entropy(quantized_dct)
    
    return {
        "raw_entropy": entropy_raw,
        "compressed_entropy": entropy_compressed,
        "compression_ratio": entropy_raw / (entropy_compressed + 1e-9)
    }
