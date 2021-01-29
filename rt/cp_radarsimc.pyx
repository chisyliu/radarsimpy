# distutils: language = c++
# cython: language_level=3


cimport cython

import numpy as np
cimport numpy as np

from libc.math cimport sin, cos, sqrt, atan, atan2, acos
from libc.math cimport pow, fmax
from libc.math cimport M_PI

from libcpp cimport bool
from libcpp.complex cimport complex as cpp_complex

from radarsimpy.includes.type_def cimport vector, complex_t
from radarsimpy.includes.type_def cimport uint64_t, float_t, int_t
from radarsimpy.includes.zpvector cimport Vec3

from radarsimpy.includes.radarsimc cimport Transmitter
from radarsimpy.includes.radarsimc cimport TxChannel
from radarsimpy.includes.radarsimc cimport RxChannel
from radarsimpy.includes.radarsimc cimport Point

cdef Point[float_t] cp_Point(location, speed, rcs, phase, shape):
    cdef vector[Vec3[float_t]] loc_vect
    cdef vector[float_t] rcs_vect
    cdef vector[float_t] phs_vect

    if np.size(location[0]) > 1 or \
        np.size(location[1])  > 1 or \
        np.size(location[2]) > 1 or \
        np.size(rcs) > 1 or \
        np.size(phase) > 1:

        if np.size(location[0]) > 1:
            tgx_t = location[0]
        else:
            tgx_t = np.full(shape, location[0])

        if np.size(location[1]) > 1:
            tgy_t = location[1]
        else:
            tgy_t = np.full(shape, location[1])
        
        if np.size(location[2]) > 1:
            tgz_t = location[2]
        else:
            tgz_t = np.full(shape, location[2])

        if np.size(rcs) > 1:
            rcs_t = rcs
        else:
            rcs_t = np.full(shape, rcs)
        
        if np.size(phase) > 1:
            phs_t = phase
        else:
            phs_t = np.full(shape, phase)

        for ch_idx in range(0, shape[0]):
            for ps_idx in range(0, shape[1]):
                for sp_idx in range(0, shape[2]):
                    loc_vect.push_back(Vec3[float_t](
                        <float_t> tgx_t[ch_idx, ps_idx, sp_idx],
                        <float_t> tgy_t[ch_idx, ps_idx, sp_idx],
                        <float_t> tgz_t[ch_idx, ps_idx, sp_idx]
                    ))
                    rcs_vect.push_back(<float_t> rcs_t[ch_idx, ps_idx, sp_idx])
                    phs_vect.push_back(<float_t> (phs_t[ch_idx, ps_idx, sp_idx]/180*np.pi))
    else:
        loc_vect.push_back(Vec3[float_t](
            <float_t> location[0],
            <float_t> location[1],
            <float_t> location[2]
        ))
        rcs_vect.push_back(<float_t> rcs)
        phs_vect.push_back(<float_t> (phase/180*np.pi))
    return Point[float_t](
                loc_vect,
                Vec3[float_t](
                    <float_t> speed[0],
                    <float_t> speed[1],
                    <float_t> speed[2]
                ),
                rcs_vect,
                phs_vect
            )


cdef Transmitter[float_t] cp_Transmitter(radar):
    cdef int_t frames = radar.frames
    cdef int_t channles = radar.channel_size
    cdef int_t pulses = radar.transmitter.pulses
    cdef int_t samples = radar.samples_per_pulse

    cdef vector[float_t] t_frame_vect
    # cdef float_t[:] t_frame_mem

    cdef vector[float_t] f_vect
    # cdef float_t[:] f_mem

    cdef vector[float_t] t_vect
    # cdef float_t[:] t_mem

    cdef vector[float_t] f_offset_vect
    # cdef float_t[:] f_offset_mem

    cdef vector[float_t] t_pstart_vect
    # cdef float_t[:] t_pstart_mem

    cdef vector[cpp_complex[float_t]] pn_vect
    # cdef complex_t[:,:,:] pn_mem

    if frames > 1:
        t_frame_mem=radar.t_offset.astype(np.float64)
        t_frame_vect.reserve(frames)
        for idx in range(0, frames):
            t_frame_vect.push_back(t_frame_mem[idx])
    else:
        t_frame_vect.push_back(<float_t> (radar.t_offset))

    f_mem = radar.f.astype(np.float64)
    f_vect.reserve(len(radar.f))
    for idx in range(0, len(radar.f)):
        f_vect.push_back(f_mem[idx])

    t_mem = radar.t.astype(np.float64)
    t_vect.reserve(len(radar.t))
    for idx in range(0, len(radar.t)):
        t_vect.push_back(t_mem[idx])

    f_offset_mem = radar.transmitter.f_offset.astype(np.float64)
    f_offset_vect.reserve(len(radar.transmitter.f_offset))
    for idx in range(0, len(radar.transmitter.f_offset)):
        f_offset_vect.push_back(f_offset_mem[idx])
    
    t_pstart_mem = radar.transmitter.chirp_start_time.astype(np.float64)
    t_pstart_vect.reserve(len(radar.transmitter.chirp_start_time))
    for idx in range(0, len(radar.transmitter.chirp_start_time)):
        t_pstart_vect.push_back(t_pstart_mem[idx])

    if radar.phase_noise is None:
        return Transmitter[float_t](
            <float_t> radar.transmitter.fc_0,
            f_vect,
            f_offset_vect,
            t_vect,
            <float_t> radar.transmitter.tx_power,
            t_pstart_vect,
            t_frame_vect,
            frames,
            pulses,
            0.0
        )
    else:
        pn_vect.reserve(frames*channles*pulses*samples)
        for idx0 in range(0, frames*channles):
            for idx1 in range(0, pulses):
                for idx2 in range(0, samples):
                    pn_vect.push_back(cpp_complex[float_t](
                        np.real(radar.phase_noise[idx0, idx1, idx2]),
                        np.imag(radar.phase_noise[idx0, idx1, idx2])
                        ))

        return Transmitter[float_t](
            <float_t> radar.transmitter.fc_0,
            f_vect,
            f_offset_vect,
            t_vect,
            <float_t> radar.transmitter.tx_power,
            t_pstart_vect,
            t_frame_vect,
            frames,
            pulses,
            0.0,
            pn_vect
        )


cdef TxChannel[float_t] cp_TxChannel(tx, tx_idx):
    cdef int_t pulses = tx.pulses

    cdef vector[float_t] az_ang_vect, az_ptn_vect
    cdef vector[float_t] el_ang_vect, el_ptn_vect

    cdef vector[cpp_complex[float_t]] pulse_mod_vect

    cdef bool mod_enabled
    cdef vector[cpp_complex[float_t]] mod_var_vect
    cdef vector[float_t] mod_t_vect

    az_ang_vect.reserve(len(tx.az_angles[tx_idx]))
    for idx in range(0, len(tx.az_angles[tx_idx])):
        az_ang_vect.push_back(<float_t> (tx.az_angles[tx_idx][idx]/180*np.pi))
    az_ptn_vect.reserve(len(tx.az_patterns[tx_idx]))
    for idx in range(0, len(tx.az_patterns[tx_idx])):
        az_ptn_vect.push_back(<float_t> (tx.az_patterns[tx_idx][idx]))

    el_ang_mem = np.flip(90-tx.el_angles[tx_idx].astype(np.float64))/180*np.pi
    el_ptn_mem = np.flip(tx.el_patterns[tx_idx].astype(np.float64))
    el_ang_vect.reserve(len(tx.el_angles[tx_idx]))
    for idx in range(0, len(tx.el_angles[tx_idx])):
        el_ang_vect.push_back(el_ang_mem[idx])
    el_ptn_vect.reserve(len(tx.el_patterns[tx_idx]))
    for idx in range(0, len(tx.el_patterns[tx_idx])):
        el_ptn_vect.push_back(el_ptn_mem[idx])

    for idx in range(0, pulses):
        pulse_mod_vect.push_back(cpp_complex[float_t](np.real(tx.pulse_mod[tx_idx, idx]), np.imag(tx.pulse_mod[tx_idx, idx])))

    mod_enabled = tx.mod[tx_idx]['enabled']
    if mod_enabled:
        for idx in range(0, len(tx.mod[tx_idx]['var'])):
            mod_var_vect.push_back(cpp_complex[float_t](np.real(tx.mod[tx_idx]['var'][idx]), np.imag(tx.mod[tx_idx]['var'][idx])))

        mod_t_vect.reserve(len(tx.mod[tx_idx]['t']))
        for idx in range(0, len(tx.mod[tx_idx]['t'])):
            mod_t_vect.push_back(<float_t> tx.mod[tx_idx]['t'][idx])
    
    return TxChannel[float_t](
        Vec3[float_t](
            <float_t> tx.locations[tx_idx, 0],
            <float_t> tx.locations[tx_idx, 1],
            <float_t> tx.locations[tx_idx, 2]
            ),
        Vec3[float_t](
            <float_t> tx.polarization[tx_idx, 0],
            <float_t> tx.polarization[tx_idx, 1],
            <float_t> tx.polarization[tx_idx, 2]
            ),
        pulse_mod_vect,
        mod_enabled,
        mod_t_vect,
        mod_var_vect,
        az_ang_vect,
        az_ptn_vect,
        el_ang_vect,
        el_ptn_vect,
        <float_t> tx.antenna_gains[tx_idx],
        <float_t> tx.delay[tx_idx],
        <float_t> (tx.grid[tx_idx]/180*np.pi)
        )


cdef RxChannel[float_t] cp_RxChannel(rx, rx_idx):
    cdef vector[float_t] az_ang_vect, az_ptn_vect
    cdef float_t[:] az_ang_mem, az_ptn_mem
    cdef vector[float_t] el_ang_vect, el_ptn_vect
    cdef float_t[:] el_ang_mem, el_ptn_mem

    az_ang_mem = rx.az_angles[rx_idx].astype(np.float64)/180*np.pi
    az_ptn_mem = rx.az_patterns[rx_idx].astype(np.float64)
    az_ang_vect.reserve(len(rx.az_angles[rx_idx]))
    for idx in range(0, len(rx.az_angles[rx_idx])):
        az_ang_vect.push_back(az_ang_mem[idx])
    az_ptn_vect.reserve(len(rx.az_patterns[rx_idx]))
    for idx in range(0, len(rx.az_patterns[rx_idx])):
        az_ptn_vect.push_back(az_ptn_mem[idx])

    el_ang_mem = np.flip(90-rx.el_angles[rx_idx].astype(np.float64))/180*np.pi
    el_ptn_mem = np.flip(rx.el_patterns[rx_idx].astype(np.float64))
    el_ang_vect.reserve(len(rx.el_angles[rx_idx]))
    for idx in range(0, len(rx.el_angles[rx_idx])):
        el_ang_vect.push_back(el_ang_mem[idx])
    el_ptn_vect.reserve(len(rx.el_patterns[rx_idx]))
    for idx in range(0, len(rx.el_patterns[rx_idx])):
        el_ptn_vect.push_back(el_ptn_mem[idx])

    return RxChannel[float_t](
                Vec3[float_t](
                    <float_t> rx.locations[rx_idx, 0],
                    <float_t> rx.locations[rx_idx, 1],
                    <float_t> rx.locations[rx_idx, 2]
                ),
                Vec3[float_t](0,0,1),
                az_ang_vect,
                az_ptn_vect,
                el_ang_vect,
                el_ptn_vect,
                <float_t> rx.antenna_gains[rx_idx]
            )