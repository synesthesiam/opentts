import typing

import numpy as np


def denormalize(
    mel_db: np.ndarray,
    symmetric_norm: bool = True,
    clip_norm: bool = True,
    max_norm: float = 1.0,
    ref_level_db: float = 20.0,
    min_level_db: float = -100.0,
) -> np.ndarray:
    """Pull values out of [0, max_norm] or [-max_norm, max_norm]"""
    if symmetric_norm:
        # Symmetric norm
        if clip_norm:
            mel_denorm = np.clip(mel_db, -max_norm, max_norm)

        mel_denorm = (
            (mel_denorm + max_norm) * -min_level_db / (2 * max_norm)
        ) + min_level_db
    else:
        # Asymmetric norm
        if clip_norm:
            mel_denorm = np.clip(mel_db, 0, max_norm)

        mel_denorm = (mel_denorm * -min_level_db / max_norm) + min_level_db

    mel_denorm += ref_level_db

    return typing.cast(np.ndarray, mel_denorm)


def dynamic_range_compression(x, C=1, clip_val=1e-5):
    """Compression function from hifi-gan training"""
    return np.log(np.clip(x, a_min=clip_val, a_max=None) * C)


def db_to_amp(mel_db: np.ndarray, spec_gain: float = 1.0) -> np.ndarray:
    return np.power(10.0, mel_db / spec_gain)


def audio_float_to_int16(
    audio: np.ndarray, max_wav_value: float = 32767.0
) -> np.ndarray:
    """Normalize audio and convert to int16 range"""
    audio_norm = audio * (max_wav_value / max(0.01, np.max(np.abs(audio))))
    audio_norm = np.clip(audio_norm, -max_wav_value, max_wav_value)
    audio_norm = audio_norm.astype("int16")
    return audio_norm


def transform(input_data):
    x = input_data
    real_part = []
    imag_part = []
    for y in x:
        y_ = stft(y, fft_size=1024, hopsamp=256).T
        real_part.append(y_.real[None, :, :])  # pylint: disable=unsubscriptable-object
        imag_part.append(y_.imag[None, :, :])  # pylint: disable=unsubscriptable-object
    real_part = np.concatenate(real_part, 0)
    imag_part = np.concatenate(imag_part, 0)

    magnitude = np.sqrt(real_part ** 2 + imag_part ** 2)
    phase = np.arctan2(imag_part.data, real_part.data)

    return magnitude, phase


def inverse(magnitude, phase):
    recombine_magnitude_phase = np.concatenate(
        [magnitude * np.cos(phase), magnitude * np.sin(phase)], axis=1
    )

    x_org = recombine_magnitude_phase
    n_b, n_f, n_t = x_org.shape  # pylint: disable=unpacking-non-sequence
    x = np.empty([n_b, n_f // 2, n_t], dtype=np.complex64)
    x.real = x_org[:, : n_f // 2]
    x.imag = x_org[:, n_f // 2 :]
    inverse_transform = []
    for y in x:
        y_ = istft(y.T, fft_size=1024, hopsamp=256)
        inverse_transform.append(y_[None, :])

    inverse_transform = np.concatenate(inverse_transform, 0)

    return inverse_transform


def stft(x, fft_size, hopsamp):
    """Compute and return the STFT of the supplied time domain signal x.
    Args:
        x (1-dim Numpy array): A time domain signal.
        fft_size (int): FFT size. Should be a power of 2, otherwise DFT will be used.
        hopsamp (int):
    Returns:
        The STFT. The rows are the time slices and columns are the frequency bins.
    """
    window = np.hanning(fft_size)
    fft_size = int(fft_size)
    hopsamp = int(hopsamp)
    return np.array(
        [
            np.fft.rfft(window * x[i : i + fft_size])
            for i in range(0, len(x) - fft_size, hopsamp)
        ]
    )


def istft(X, fft_size, hopsamp):
    """Invert a STFT into a time domain signal.
    Args:
        X (2-dim Numpy array): Input spectrogram. The rows are the time slices and columns are the frequency bins.
        fft_size (int):
        hopsamp (int): The hop size, in samples.
    Returns:
        The inverse STFT.
    """
    fft_size = int(fft_size)
    hopsamp = int(hopsamp)
    window = np.hanning(fft_size)
    time_slices = X.shape[0]
    len_samples = int(time_slices * hopsamp + fft_size)
    x = np.zeros(len_samples)
    for n, i in enumerate(range(0, len(x) - fft_size, hopsamp)):
        x[i : i + fft_size] += window * np.real(np.fft.irfft(X[n]))
    return x
