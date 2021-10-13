from typing import Dict

import torch

from TTS.utils.audio import AudioProcessor


def interpolate_vocoder_input(scale_factor, spec):
    """Interpolate spectrogram by the scale factor.
    It is mainly used to match the sampling rates of
    the tts and vocoder models.

    Args:
        scale_factor (float): scale factor to interpolate the spectrogram
        spec (np.array): spectrogram to be interpolated

    Returns:
        torch.tensor: interpolated spectrogram.
    """
    print(" > before interpolation :", spec.shape)
    spec = torch.tensor(spec).unsqueeze(0).unsqueeze(0)  # pylint: disable=not-callable
    spec = torch.nn.functional.interpolate(
        spec,
        scale_factor=scale_factor,
        recompute_scale_factor=True,
        mode="bilinear",
        align_corners=False,
    ).squeeze(0)
    print(" > after interpolation :", spec.shape)
    return spec


def plot_results(
    y_hat: torch.tensor, y: torch.tensor, ap: AudioProcessor, name_prefix: str = None
) -> Dict:
    """Plot the predicted and the real waveform and their spectrograms.

    Args:
        y_hat (torch.tensor): Predicted waveform.
        y (torch.tensor): Real waveform.
        ap (AudioProcessor): Audio processor used to process the waveform.
        name_prefix (str, optional): Name prefix used to name the figures. Defaults to None.

    Returns:
        Dict: output figures keyed by the name of the figures.
    """ """Plot vocoder model results"""
    raise NotImplementedError()
